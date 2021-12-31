# Copyright 2021 CodeNotary, Inc. All rights reserved.

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

    def list_users
      permission_map = PERMISSION.invert
      grpc.list_users(Google::Protobuf::Empty.new).users.map do |user|
        {
          user: user.user,
          permissions: user.permissions.map { |v| {database: v.database, permission: permission_map.fetch(v.permission)} },
          created_by: user.createdby,
          created_at: Time.parse(user.createdat),
          active: user.active
        }
      end
    end

    def create_user(user, password:, permission:, database:)
      req = Schema::CreateUserRequest.new(user: user, password: password, permission: PERMISSION.fetch(permission), database: database)
      grpc.create_user(req)
      nil
    end

    def change_password(user, old_password:, new_password:)
      req = Schema::ChangePasswordRequest.new(user: user, oldPassword: old_password, newPassword: new_password)
      grpc.change_password(req)
      nil
    end

    def set(key, value)
      req = Schema::SetRequest.new(KVs: [Schema::KeyValue.new(key: key, value: value)])
      grpc.set(req)
      nil
    end

    def verified_set(key, value)
      state = @rs.get
      kv = Schema::KeyValue.new(key: key, value: value)

      raw_request = Schema::VerifiableSetRequest.new(
        setRequest: Schema::SetRequest.new(KVs: [kv]),
        proveSinceTx: state.txId
      )
      verifiable_tx = grpc.verifiable_set(raw_request)
      tx = Store.tx_from(verifiable_tx.tx)
      inclusion_proof = tx.proof(SET_KEY_PREFIX + key)
      ekv = Store.encode_kv(key, value)
      verifies = Store.verify_inclusion(inclusion_proof, ekv.digest, tx.eh)
      unless verifies
        raise VerificationError
      end
      if tx.eh != Store.digest_from(verifiable_tx.dualProof.targetTxMetadata.eH)
        raise VerificationError
      end
      if state.txId == 0
        source_id = tx.ID
        source_alh = tx.Alh
      else
        source_id = state.txId
        source_alh = Store.digest_from(state.txHash)
      end
      target_id = tx.ID
      target_alh = tx.Alh

      verifies = Store.verify_dual_proof(
        HTree.dual_proof_from(verifiable_tx.dualProof),
        source_id,
        target_id,
        source_alh,
        target_alh
      )
      if !verifies
        raise VerificationError
      end
      newstate = State.new(
        db: state.db,
        txId: target_id,
        txHash: target_alh,
        publicKey: verifiable_tx.signature&.publicKey,
        signature: verifiable_tx.signature&.signature,
      )
      if !verifying_key.nil?
        newstate.verify(verifying_key)
      end
      @rs.set(newstate)
      nil
    end

    def get(key)
      req = Schema::KeyRequest.new(key: key)
      grpc.get(req).value
    end

    def verified_get(key)
      state = @rs.get
      req = Schema::VerifiableGetRequest.new(
        keyRequest: Schema::KeyRequest.new(key: key),
        proveSinceTx: state.txId
      )
      ventry = grpc.verifiable_get(req)

      inclusion_proof = HTree.inclusion_proof_from(ventry.inclusionProof)
      dual_proof = HTree.dual_proof_from(ventry.verifiableTx.dualProof)

      if ventry.entry.referencedBy.nil? || ventry.entry.referencedBy.key == ""
        vTx = ventry.entry.tx
        kv = Store.encode_kv(key, ventry.entry.value)
      else
        vTx = ventry.entry.referencedBy.tx
        kv = store.encode_reference(ventry.entry.referencedBy.key, ventry.entry.key, ventry.entry.referencedBy.atTx)
      end

      if state.txId <= vTx
        eh = Store.digest_from(ventry.verifiableTx.dualProof.targetTxMetadata.eH)
        source_id = state.txId
        source_alh = Store.digest_from(state.txHash)
        target_id = vTx
        target_alh = dual_proof.targetTxMetadata.alh
      else
        eh = Store.digest_from(ventry.verifiableTx.dualProof.sourceTxMetadata.eH)
        source_id = vTx
        source_alh = dual_proof.sourceTxMetadata.alh
        target_id = state.txId
        target_alh = store.digest_from(state.txHash)
      end

      verifies = Store.verify_inclusion(inclusion_proof, kv.digest, eh)
      if !verifies
        raise VerificationError
      end
      verifies = Store.verify_dual_proof(
          dual_proof,
          source_id,
          target_id,
          source_alh,
          target_alh)
      if !verifies
        raise VerificationError
      end
      newstate = State.new(
        db: state.db,
        txId: target_id,
        txHash: target_alh,
        publicKey: ventry.verifiableTx.signature&.publicKey,
        signature: ventry.verifiableTx.signature&.signature,
      )
      if !verifying_key.nil?
        newstate.verify(verifying_key)
      end
      @rs.set(newstate)

      ventry.entry.value
    end

    def set_all(values)
      req = Schema::SetRequest.new(KVs: values.map { |k, v| Schema::KeyValue.new(key: k, value: v) })
      grpc.set(req)
      nil
    end

    def get_all(keys)
      req = Schema::KeyListRequest.new(keys: keys)
      grpc.get_all(req).entries.to_h { |v| [v.key, v.value] }
    end

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

    def scan(seek_key: nil, prefix: nil, desc: false, limit: nil, since_tx: nil, no_wait: false)
      req = Schema::ScanRequest.new(seekKey: seek_key, prefix: prefix, desc: desc, limit: limit, sinceTx: since_tx, noWait: no_wait)
      grpc.scan(req).entries.map do |entry|
        {
          tx: entry.tx,
          key: entry.key,
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

    # sql

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
  end
end
