module Immudb
  module Client::KeyValueMethods
    def set(key, value)
      req = Schema::SetRequest.new(KVs: [Schema::KeyValue.new(key: key, value: value)])
      grpc.set(req)
      nil
    end

    def verified_set(key, value, metadata: nil)
      schema_metadata = metadata_to_proto(metadata)
      state = @rs.get
      kv = Schema::KeyValue.new(key: key, value: value, metadata: schema_metadata)

      raw_request = Schema::VerifiableSetRequest.new(
        setRequest: Schema::SetRequest.new(KVs: [kv]),
        proveSinceTx: state.txId
      )
      verifiable_tx = grpc.verifiable_set(raw_request)
      if verifiable_tx.tx.header.nentries != 1 || verifiable_tx.tx.entries.length != 1
        raise VerificationError
      end
      tx = Schema.tx_from_proto(verifiable_tx.tx)
      entry_spec_digest = Store.entry_spec_digest_for(tx.header.version)
      inclusion_proof = tx.proof(Database.encode_key(key))
      md = tx.entries[0].metadata

      if !md.nil? && md.deleted?
        raise VerificationError
      end

      e = Database.encode_entry_spec(key, md, value)

      verifies = Store.verify_inclusion(inclusion_proof, entry_spec_digest.call(e), tx.header.eh)
      unless verifies
        raise VerificationError
      end
      if tx.header.eh != Schema.digest_from_proto(verifiable_tx.dualProof.targetTxHeader.eH)
        raise VerificationError
      end
      source_id = state.txId
      source_alh = Schema.digest_from_proto(state.txHash)
      target_id = tx.header.iD
      target_alh = tx.header.alh

      if state.txId > 0
        verifies = Store.verify_dual_proof(
          Schema.dual_proof_from_proto(verifiable_tx.dualProof),
          source_id,
          target_id,
          source_alh,
          target_alh
        )
        unless verifies
          raise VerificationError
        end
      end

      newstate = State.new(
        db: state.db,
        txId: target_id,
        txHash: target_alh,
        publicKey: verifiable_tx.signature&.publicKey,
        signature: verifiable_tx.signature&.signature
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

      entry_spec_digest = Store.entry_spec_digest_for(ventry.verifiableTx.tx.header.version.to_i)
      inclusion_proof = Schema.inclusion_proof_from_proto(ventry.inclusionProof)
      dual_proof = Schema.dual_proof_from_proto(ventry.verifiableTx.dualProof)

      if ventry.entry.referencedBy.nil? || ventry.entry.referencedBy.key == ""
        vTx = ventry.entry.tx
        e = Database.encode_entry_spec(key, Schema.kv_metadata_from_proto(ventry.entry.metadata), ventry.entry.value)
      else
        ref = ventry.entry.referencedBy
        vTx = ref.tx
        e = Database.encode_reference(ref.key, Schema.kv_metadata_from_proto(ref.metadata), ventry.entry.key, ref.atTx)
      end

      if state.txId <= vTx
        eh = Schema.digest_from_proto(ventry.verifiableTx.dualProof.targetTxHeader.eH)
        source_id = state.txId
        source_alh = Schema.digest_from_proto(state.txHash)
        target_id = vTx
        target_alh = dual_proof.targetTxHeader.alh
      else
        eh = Schema.digest_from_proto(ventry.verifiableTx.dualProof.sourceTxHeader.eH)
        source_id = vTx
        source_alh = dual_proof.sourceTxHeader.alh
        target_id = state.txId
        target_alh = Schema.digest_from_proto(state.txHash)
      end

      verifies = Store.verify_inclusion(inclusion_proof, entry_spec_digest.call(e), eh)
      if !verifies
        raise VerificationError
      end

      if state.txId > 0
        verifies =
          Store.verify_dual_proof(
            dual_proof,
            source_id,
            target_id,
            source_alh,
            target_alh
          )
        if !verifies
          raise VerificationError
        end
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
  end
end
