# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require "tmpdir"
require "spec_helper"
require "logstash/codecs/plain"
require_relative "../support/mocks_classes"

class SingleGeneratorInput < LogStash::Inputs::Base
  config_name "singlegenerator"
  milestone 2

  def register
  end

  def run(queue)
    queue << LogStash::Event.new
  end

  def close
  end
end

class DLQCommittingFilter < LogStash::Filters::Base
  config_name "dlq_commit"
  milestone 2

  def register()
  end

  def filter(event)
    execution_context.dlq_writer.write(event, "my reason")
  end

  def threadsafe?() true; end

  def close() end
end

describe LogStash::JavaPipeline do
  let(:pipeline_settings_obj) { LogStash::SETTINGS.clone }
  let(:pipeline_settings) do
    {
      "pipeline.workers" => 2,
      "pipeline.id" => pipeline_id,
      "dead_letter_queue.enable" => enable_dlq,
      "path.dead_letter_queue" => Dir.mktmpdir
    }
  end
  let(:metric) { LogStash::Instrument::Metric.new(LogStash::Instrument::Collector.new) }
  let(:test_config) {
    <<-eos
        input { singlegenerator { id => input_id } }

        filter { dlq_commit { id => filter_id } }

        output { dummyoutput { id => output_id } }
    eos
  }

  subject { mock_java_pipeline_from_string(test_config, pipeline_settings_obj, metric) }

  before(:each) do
    pipeline_settings.each {|k, v| pipeline_settings_obj.set(k, v) }
    allow(LogStash::Plugin).to receive(:lookup).with("input", "singlegenerator").and_return(SingleGeneratorInput)
    allow(LogStash::Plugin).to receive(:lookup).with("codec", "plain").and_return(LogStash::Codecs::Plain)
    allow(LogStash::Plugin).to receive(:lookup).with("filter", "dlq_commit").and_return(DLQCommittingFilter)
    allow(LogStash::Plugin).to receive(:lookup).with("output", "dummyoutput").and_return(::LogStash::Outputs::DummyOutput)
  end

  after(:each) do
    FileUtils.rm_rf(pipeline_settings["path.dead_letter_queue"])
  end

  context "dlq is enabled" do
    let(:enable_dlq) { true }
    let(:pipeline_id) { "test-dlq" }

    it "retrieves proper pipeline-level DLQ writer" do
      expect_any_instance_of(org.logstash.common.io.DeadLetterQueueWriter).to receive(:close).at_least(:once).and_call_original
      subject.start
      subject.shutdown
      dlq_path = java.nio.file.Paths.get(pipeline_settings_obj.get("path.dead_letter_queue"), pipeline_id)
      dlq_reader = org.logstash.common.io.DeadLetterQueueReader.new(dlq_path)
      entry = dlq_reader.pollEntry(40)
      expect(entry).to_not be_nil
      expect(entry.reason).to eq("my reason")
    end
  end

  context "dlq is disabled" do
    let(:enable_dlq) { false }
    let(:pipeline_id) { "test-without-dlq" }

    it "does not write to the DLQ" do
      expect(LogStash::Util::DummyDeadLetterQueueWriter).to receive(:new).and_call_original
      expect_any_instance_of(LogStash::Util::DummyDeadLetterQueueWriter).to receive(:close).at_least(:once).and_call_original
      subject.start
      dlq_path = java.nio.file.Paths.get(pipeline_settings_obj.get("path.dead_letter_queue"), pipeline_id)
      expect(java.nio.file.Files.exists(dlq_path)).to eq(false)
      subject.shutdown
    end
  end
end
