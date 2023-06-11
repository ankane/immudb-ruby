module Immudb
  module Client::SQLMethods
    def sql_exec(sql, params = {})
      req = Schema::SQLExecRequest.new(sql: sql, params: sql_params(params))
      grpc.sql_exec(req)
      nil
    end

    def sql_query(sql, params = {})
      req = Schema::SQLQueryRequest.new(sql: sql, params: sql_params(params))
      res = grpc.sql_query(req)
      sql_result(res)
    end

    def list_tables
      grpc.list_tables(Google::Protobuf::Empty.new).rows.map { |r| r.values.first.s }
    end

    def describe_table(name)
      req = Schema::Table.new(tableName: name)
      res = grpc.describe_table(req)
      sql_result(res).to_a
    end
  end
end
