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
  module Schema
    class << self
      def tx_from_proto(stx)
        header = ::Immudb::TxHeader.new
        header.iD = stx.header.id
        header.ts = stx.header.ts
        header.blTxID = stx.header.blTxId
        header.blRoot = digest_from_proto(stx.header.blRoot)
        header.prevAlh = digest_from_proto(stx.header.prevAlh)

        header.version = stx.header.version.to_i
        header.metadata = tx_metadata_from_proto(stx.header.metadata)

        header.nentries = stx.header.nentries.to_i
        header.eh = digest_from_proto(stx.header.eH)

        entries = []
        stx.entries.each do |e|
          entries <<
            ::Immudb::TxEntry.new(
              e.key,
              kv_metadata_from_proto(e.metadata),
              e.vLen.to_i,
              digest_from_proto(e.hValue),
              0
            )
        end

        tx = Store.new_tx_with_entries(header, entries)

        tx.build_hash_tree

        tx
      end

      def kv_metadata_from_proto(md)
        return nil if md.nil?
        raise "Not supported yet"
        kvmd = KVMetadata.new()
        kvmd.as_deleted(md.deleted)

        if md.HasField("expiration")
          kvmd.expires_at(datetime.utcfromtimestamp(md.expiration.expiresAt))
        end

        kvmd.as_non_indexable(md.nonIndexable)

        kvmd
      end

      def inclusion_proof_from_proto(iproof)
        ip = ::Immudb::InclusionProof.new
        ip.leaf = iproof.leaf.to_i
        ip.width = iproof.width.to_i
        ip.terms = digests_from_proto(iproof.terms)
        ip
      end

      def dual_proof_from_proto(dproof)
        dp = ::Immudb::DualProof.new
        dp.sourceTxHeader = tx_header_from_proto(dproof.sourceTxHeader)
        dp.targetTxHeader = tx_header_from_proto(dproof.targetTxHeader)
        dp.inclusionProof = digests_from_proto(dproof.inclusionProof)
        dp.consistencyProof = digests_from_proto(dproof.consistencyProof)
        dp.targetBlTxAlh = digest_from_proto(dproof.targetBlTxAlh)
        dp.lastInclusionProof = digests_from_proto(dproof.lastInclusionProof)
        dp.linearProof = linear_proof_from_proto(dproof.linearProof)
        dp
      end

      def tx_header_from_proto(hdr)
        txh = ::Immudb::TxHeader.new
        txh.iD = hdr.id
        txh.prevAlh = digest_from_proto(hdr.prevAlh)
        txh.ts = hdr.ts
        txh.version = hdr.version.to_i
        txh.metadata = tx_metadata_from_proto(hdr.metadata)
        txh.nentries = hdr.nentries.to_i
        txh.eh = digest_from_proto(hdr.eH)
        txh.blTxID = hdr.blTxId
        txh.blRoot = digest_from_proto(hdr.blRoot)
        txh
      end

      def tx_metadata_from_proto(md)
        return nil if md.nil?
        ::Immudb::TxMetadata.new
      end

      def linear_proof_from_proto(lproof)
        lp = ::Immudb::LinearProof.new
        lp.sourceTxID = lproof.sourceTxId
        lp.targetTxID = lproof.TargetTxId
        lp.terms = digests_from_proto(lproof.terms)
        lp
      end

      def digest_from_proto(sliced_digest)
        sliced_digest[0, 32]
      end

      def digests_from_proto(sliced_terms)
        sliced_terms.map(&:dup)
      end
    end
  end
end
