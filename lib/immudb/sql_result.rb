module Immudb
  class SqlResult
    attr_reader :columns, :rows, :column_types

    def initialize(columns, rows, column_types)
      @columns = columns
      @rows = rows
      @column_types = column_types
    end

    def to_a
      @rows.map { |r| @columns.zip(r).to_h }
    end
  end
end
