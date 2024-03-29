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

module LogStashCompilerLSCLGrammar; module LogStash; module Compiler; module LSCL; module AST
  # Helpers for parsing LSCL files
  module Helpers
    def source_meta
      line, column = line_and_column
      org.logstash.common.SourceWithMetadata.new(base_protocol, base_id, line, column, self.text_value)
    end

    def base_source_with_metadata=(value)
      set_meta(:base_source_with_metadata, value)
    end

    def base_source_with_metadata
      get_meta(:base_source_with_metadata)
    end

    def base_protocol
      self.base_source_with_metadata ? self.base_source_with_metadata.protocol : 'config_ast'
    end

    def base_id
      self.base_source_with_metadata ? self.base_source_with_metadata.id : 'config_ast'
    end

    def compose(*statements)
      compose_for(section_type.to_sym).call(source_meta, *statements)
    end

    def compose_for(section_sym)
      if section_sym == :filter
        jdsl.method(:iComposeSequence)
      else
        jdsl.method(:iComposeParallel)
      end
    end

    def line_and_column
      start = self.interval.first
      [self.input.line_of(start), self.input.column_of(start)]
    end

    def jdsl
      org.logstash.config.ir.DSL
    end

    def self.jdsl
      org.logstash.config.ir.DSL
    end

    BOOLEAN_DSL_METHOD_SIGNATURE = [org.logstash.common.SourceWithMetadata, org.logstash.config.ir.expression.Expression, org.logstash.config.ir.expression.Expression]
    AND_METHOD = jdsl.java_method(:eAnd, BOOLEAN_DSL_METHOD_SIGNATURE)
    NAND_METHOD = jdsl.java_method(:eNand, BOOLEAN_DSL_METHOD_SIGNATURE)
    OR_METHOD = jdsl.java_method(:eOr, BOOLEAN_DSL_METHOD_SIGNATURE)
    XOR_METHOD = jdsl.java_method(:eXor, BOOLEAN_DSL_METHOD_SIGNATURE)
  end
end; end; end; end; end
