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
  class Store
    class << self
      def new_tx_with_entries(header, entries)
        htree = HTree.new(entries.length)

        tx = Tx.new
        tx.header = header
        tx.entries = entries
        tx.htree = htree
        tx
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
        if proof.nil? || proof.sourceTxHeader.nil? || proof.targetTxHeader.nil? || proof.sourceTxHeader.iD != sourceTxID || proof.targetTxHeader.iD != targetTxID
          return false
        end
        if proof.sourceTxHeader.iD == 0 || proof.sourceTxHeader.iD > proof.targetTxHeader.iD
          return false
        end
        if sourceAlh != proof.sourceTxHeader.alh
          return false
        end
        if targetAlh != proof.targetTxHeader.alh
          return false
        end
        if sourceTxID < proof.targetTxHeader.blTxID && !verify_inclusion_aht(proof.inclusionProof, sourceTxID, proof.targetTxHeader.blTxID, leaf_for(sourceAlh), proof.targetTxHeader.blRoot)
          return false
        end
        if proof.sourceTxHeader.blTxID > 0 && !verify_consistency(proof.consistencyProof, proof.sourceTxHeader.blTxID, proof.targetTxHeader.blTxID, proof.sourceTxHeader.blRoot, proof.targetTxHeader.blRoot)
          return false
        end
        if proof.targetTxHeader.blTxID > 0 && !verify_last_inclusion(proof.lastInclusionProof, proof.targetTxHeader.blTxID, leaf_for(proof.targetBlTxAlh), proof.targetTxHeader.blRoot)
          return false
        end
        if sourceTxID < proof.targetTxHeader.blTxID
          verify_linear_proof(proof.linearProof, proof.targetTxHeader.blTxID, targetTxID, proof.targetBlTxAlh, targetAlh)
        else
          verify_linear_proof(proof.linearProof, sourceTxID, targetTxID, sourceAlh, targetAlh)
        end
      end

      def entry_spec_digest_for(version)
        if version == 0
          method(:entry_spec_digest_v0)
        elsif version == 1
          method(:entry_spec_digest_v1)
        else
          # TODO raise ErrUnsupportedTxVersion
          raise VerificationError
        end
      end

      def entry_spec_digest_v0(kv)
        md = Digest::SHA256.new
        md.update(kv.key)
        valmd = Digest::SHA256.new
        valmd.update(kv.value)
        md.update(valmd.digest)
        md.digest
      end

      def entry_spec_digest_v1(kv)
        mdbs = "".b
        if !kv.metadata.nil?
          raise "Not supported yet"
          # mdbs = kv.metadata.Bytes()
        end
        mdLen = mdbs.length
        kLen = kv.key.length
        b = "".b
        b = b + [mdLen].pack("n")
        b = b + mdbs
        b = b + [kLen].pack("n")
        b = b + kv.key

        md = Digest::SHA256.new
        md.update(b)
        valmd = Digest::SHA256.new
        valmd.update(kv.value)
        md.update(valmd.digest)
        md.digest
      end

      private

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
