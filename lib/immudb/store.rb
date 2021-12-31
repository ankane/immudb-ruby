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
  class Store
    class << self
      def tx_from(stx)
        entries = []
        stx.entries.each do |e|
          i = TXe.new
          i.h_value = digest_from(e.hValue)
          i.v_off = e.vOff
          i.value_len = e.vLen.to_i
          i.set_key(e.key)
          entries << i
        end
        tx = new_tx_with_entries(entries)
        tx.ID = stx.metadata.id
        tx.PrevAlh = digest_from(stx.metadata.prevAlh)
        tx.Ts = stx.metadata.ts
        tx.BlTxID = stx.metadata.blTxId
        tx.BlRoot = digest_from(stx.metadata.blRoot)
        tx.build_hash_tree
        tx.calc_alh
        tx
      end

      def tx_metadata_from(txmFrom)
        txm = TxMetadata.new
        txm.iD = txmFrom.id
        txm.prevAlh = digest_from(txmFrom.prevAlh)
        txm.ts = txmFrom.ts
        txm.nEntries = txmFrom.nentries.to_i
        txm.eh = digest_from(txmFrom.eH)
        txm.blTxID = txmFrom.blTxId
        txm.blRoot = digest_from(txmFrom.blRoot)
        txm
      end

      def encode_key(key)
        SET_KEY_PREFIX + key
      end

      def encode_kv(key, value)
        KV.new(SET_KEY_PREFIX + key, PLAIN_VALUE_PREFIX + value)
      end

      def encode_reference(key, referencedKey, atTx)
        refVal = REFERENCE_VALUE_PREFIX + [atTx].pack("Q>") + SET_KEY_PREFIX + referencedKey
        KV.new(SET_KEY_PREFIX + key, refVal)
      end

      def linear_proof_from(lp)
        LinearProof.new(lp.sourceTxId, lp.TargetTxId, lp.terms)
      end

      def digest_from(sliced_digest)
        sliced_digest[0, 32]
      end

      def digests_from(sliced_terms)
        sliced_terms.map(&:dup)
      end

      def verify_inclusion(proof, digest, root)
        return false if proof.nil?
        leaf = LEAF_PREFIX + digest
        calc_root = Digest::SHA256.digest(leaf)
        i = proof.leaf
        r = proof.width - 1
        proof.terms.to_a.each do |t|
          b = NODE_PREFIX
          if i % 2 == 0 && i != r
            b = b + calc_root + t
          else
            b = b + t + calc_root
          end
          calc_root = Digest::SHA256.digest(b)
          i = i.div(2)
          r = r.div(2)
        end
        i == r && root == calc_root
      end

      def verify_dual_proof(proof, sourceTxID, targetTxID, sourceAlh, targetAlh)
        if proof.nil? || proof.sourceTxMetadata.nil? || proof.targetTxMetadata.nil? || proof.sourceTxMetadata.iD != sourceTxID || proof.targetTxMetadata.iD != targetTxID
          return false
        end
        if proof.sourceTxMetadata.iD == 0 || proof.sourceTxMetadata.iD > proof.targetTxMetadata.iD
          return false
        end
        if sourceAlh != proof.sourceTxMetadata.alh
          return false
        end
        if targetAlh != proof.targetTxMetadata.alh
          return false
        end
        if sourceTxID < proof.targetTxMetadata.blTxID && !verify_inclusion_aht(proof.inclusionProof, sourceTxID, proof.targetTxMetadata.blTxID, leaf_for(sourceAlh), proof.targetTxMetadata.blRoot)
          return false
        end
        if proof.sourceTxMetadata.blTxID > 0 && !verify_consistency(proof.consistencyProof, proof.sourceTxMetadata.blTxID, proof.targetTxMetadata.blTxID, proof.sourceTxMetadata.blRoot, proof.targetTxMetadata.blRoot)
          return false
        end
        if proof.targetTxMetadata.blTxID > 0 && !verify_last_inclusion(proof.lastInclusionProof, proof.targetTxMetadata.blTxID, leaf_for(proof.targetBlTxAlh), proof.targetTxMetadata.blRoot)
          return false
        end
        if sourceTxID < proof.targetTxMetadata.blTxID
          verify_linear_proof(proof.linearProof, proof.targetTxMetadata.blTxID, targetTxID, proof.targetBlTxAlh, targetAlh)
        else
          verify_linear_proof(proof.linearProof, sourceTxID, targetTxID, sourceAlh, targetAlh)
        end
      end

      private

      def new_tx_with_entries(entries)
        tx = Tx.new
        tx.ID = 0
        tx.entries = entries
        tx.nentries = entries.length
        tx.htree = HTree.new(entries.length)
        tx
      end

      def leaf_for(d)
        b = LEAF_PREFIX + d
        Digest::SHA256.digest(b)
      end

      def verify_inclusion_aht(iproof, i, j, iLeaf, jRoot)
        if i > j || i == 0 || i < j && iproof.length == 0
          return false
        end
        i1 = i - 1
        j1 = j - 1
        ciRoot = iLeaf
        iproof.each do |h|
          if i1 % 2 == 0 && i1 != j1
            b = NODE_PREFIX + ciRoot + h
          else
            b = NODE_PREFIX + h + ciRoot
          end
          ciRoot = Digest::SHA256.digest(b)
          i1 = i1 >> 1
          j1 = j1 >> 1
        end
        jRoot == ciRoot
      end

      def verify_consistency(cproof, i, j, iRoot, jRoot)
        if i > j || i == 0 || (i < j && cproof.length == 0)
          return false
        end
        if i == j && cproof.length == 0
          return iRoot == jRoot
        end

        fn = i - 1
        sn = j - 1
        while fn % 2 == 1
          fn = fn >> 1
          sn = sn >> 1
        end
        ciRoot, cjRoot = cproof[0], cproof[0]
        cproof[1..-1].each do |h|
          if fn % 2 == 1 || fn == sn
            b = NODE_PREFIX + h + ciRoot
            ciRoot = Digest::SHA256.digest(b)
            b = NODE_PREFIX + h + cjRoot
            cjRoot = Digest::SHA256.digest(b)
            while fn % 2 == 0 && fn != 0
              fn = fn >> 1
              sn = sn >> 1
            end
          else
            b = NODE_PREFIX + cjRoot + h
            cjRoot = Digest::SHA256.digest(b)
          end
          fn = fn >> 1
          sn = sn >> 1
        end
        iRoot == ciRoot && jRoot == cjRoot
      end

      def verify_last_inclusion(iproof, i, leaf, root)
        if i == 0
          return false
        end
        i1 = i - 1
        iroot = leaf
        iproof.each do |h|
          b = NODE_PREFIX + h + iroot
          iroot = Digest::SHA256.digest(b)
          i1 >>= 1
        end
        root == iroot
      end

      def verify_linear_proof(proof, sourceTxID, targetTxID, sourceAlh, targetAlh)
        if proof.nil? || proof.sourceTxID != sourceTxID || proof.targetTxID != targetTxID
          return false
        end

        if proof.sourceTxID == 0 || proof.sourceTxID > proof.targetTxID || proof.terms.length == 0 || sourceAlh != proof.terms[0]
          return false
        end

        calculatedAlh = proof.terms[0]
        (1...proof.terms.length).each do |i|
          bs = [proof.sourceTxID + i].pack("Q>") + calculatedAlh + proof.terms[i]
          calculatedAlh = Digest::SHA256.digest(bs)
        end

        targetAlh == calculatedAlh
      end
    end
  end
end
