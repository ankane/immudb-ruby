module Immudb
  module Client::DatabasesMethods
    def create_database(name)
      req = Schema::Database.new(databaseName: name)
      grpc.create_database(req)
      nil
    end

    def list_databases
      grpc.database_list(Google::Protobuf::Empty.new).databases.map(&:databaseName)
    end

    def use_database(name)
      req = Schema::Database.new(databaseName: name)
      res = grpc.use_database(req)
      interceptor.token = res.token
      @rs.init(name, grpc)
      nil
    end
  end
end
