# stdlib
require "net/http"
require "openssl"
require "time"

# grpc
require_relative "immudb/grpc/schema_services_pb"

# modules
require_relative "immudb/client"
require_relative "immudb/constants"
require_relative "immudb/database"
require_relative "immudb/dual_proof"
require_relative "immudb/entry_spec"
require_relative "immudb/htree"
require_relative "immudb/inclusion_proof"
require_relative "immudb/interceptor"
require_relative "immudb/kv"
require_relative "immudb/kv_metadata"
require_relative "immudb/linear_proof"
require_relative "immudb/root_service"
require_relative "immudb/schema"
require_relative "immudb/sql_result"
require_relative "immudb/state"
require_relative "immudb/store"
require_relative "immudb/tx"
require_relative "immudb/tx_entry"
require_relative "immudb/tx_header"
require_relative "immudb/tx_metadata"
require_relative "immudb/version"

module Immudb
  class Error < StandardError; end
  class VerificationError < Error
    def message
      "Verification failed"
    end
  end
end
