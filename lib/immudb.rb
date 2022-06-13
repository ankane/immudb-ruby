# stdlib
require "net/http"
require "openssl"
require "time"

# grpc
require "immudb/grpc/schema_services_pb"

# modules
require "immudb/client"
require "immudb/constants"
require "immudb/database"
require "immudb/dual_proof"
require "immudb/entry_spec"
require "immudb/htree"
require "immudb/inclusion_proof"
require "immudb/interceptor"
require "immudb/kv"
require "immudb/linear_proof"
require "immudb/root_service"
require "immudb/schema"
require "immudb/sql_result"
require "immudb/state"
require "immudb/store"
require "immudb/tx"
require "immudb/tx_entry"
require "immudb/tx_header"
require "immudb/tx_metadata"
require "immudb/txe"
require "immudb/version"

module Immudb
  class Error < StandardError; end
  class VerificationError < Error
    def message
      "Verification failed"
    end
  end
end
