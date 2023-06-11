# Copyright 2022 CodeNotary, Inc. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#       http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Immudb
  class Client
    require_relative 'client/databases_methods'
    require_relative 'client/key_value_methods'
    require_relative 'client/sql_methods'
    require_relative 'client/users_methods'
    include DatabasesMethods
    include KeyValueMethods
    include SQLMethods
    include UsersMethods

    def initialize(url: nil, host: nil, port: nil, username: nil, password: nil, database: nil, timeout: nil, rs: nil)
      url ||= ENV["IMMUDB_URL"]
      if url
        uri = URI.parse(url)

        if uri.scheme != "immudb"
          raise ArgumentError, "Expected url to start with immudb://"
        end

        host ||= uri.host
        port ||= uri.port
        username ||= uri.username
        password ||= uri.password
        database ||= uri.path.sub(/\A\//, "")
      end

      host ||= "localhost"
      port ||= 3322
      username ||= "immudb"
      password ||= "immudb"
      database ||= "defaultdb"

      raise ArgumentError, "Invalid host" if host.include?(":")

      @rs = rs || RootService.new

      @interceptor = Interceptor.new
      @grpc = Schema::ImmuService::Stub.new("#{host}:#{port.to_i}", :this_channel_is_insecure, timeout: timeout, interceptors: [interceptor])

      login(username, password)
      use_database(database)
    end

    # history
    def history(key, offset: nil, limit: nil, desc: false)
      req = Schema::HistoryRequest.new(key: key, offset: offset, limit: limit, desc: desc)
      grpc.history(req).entries.map do |entry|
        {
          tx: entry.tx,
          value: entry.value
        }
      end
    end

    # management
    def clean_index
      grpc.compact_index(Google::Protobuf::Empty.new)
      nil
    end

    def healthy?
      grpc.health(Google::Protobuf::Empty.new).status
    rescue Error
      false
    end

    def version
      grpc.health(Google::Protobuf::Empty.new).version
    end

    # hide token
    def inspect
      to_s
    end

    private

    def grpc
      @grpc
    end

    def interceptor
      @interceptor
    end

    def verifying_key
      nil
    end

    # keep private for now
    # if public, need to call use_database
    def login(user, password)
      req = Schema::LoginRequest.new(user: user, password: password)
      res = grpc.login(req)
      interceptor.token = res.token

      # warn "[immudb] #{res.warning}" if res.warning

      res
    end

    def logout
      res = grpc.logout(Google::Protobuf::Empty.new)
      interceptor.token = nil
      res
    end

    def sql_params(params)
      params.map do |k, v|
        Schema::NamedParam.new(name: k, value: sql_value(v))
      end
    end

    def sql_value(v)
      opts =
        case v
        when nil
          {null: :NULL_VALUE}
        when Integer
          {n: v}
        when String
          {s: v}
        when true, false
          {b: v}
        else
          raise ArgumentError, "Unsupported param type: #{v.class.name}"
        end
      Schema::SQLValue.new(**opts)
    end

    def sql_result(res)
      columns = res.columns.map { |v| sql_column_name(v.name) }
      rows = res.rows.map { |r| r.values.map { |v| v.value == :null ? nil : v.send(v.value) } }
      column_types = res.columns.to_h { |v| [v.name, v.type] }
      SqlResult.new(columns, rows, column_types)
    end

    def sql_column_name(name)
      if name.start_with?("(") && name.end_with?(")")
        name.split(".").last.chomp(")")
      else
        name
      end
    end

    def metadata_to_proto(metadata)
      schema_metadata = nil
      if metadata
        schema_metadata = Schema::KVMetadata.new
        if metadata.deleted?
          schema_metadata.deleted = true
        end
        if metadata.expirable?
          schema_metadata.expiration = Schema::Expiration.new(expiresAt: metadata.expiration_time.to_i)
        end
        if metadata.non_indexable?
          schema_metadata.nonIndexable = true
        end
      end
      schema_metadata
    end
  end
end
