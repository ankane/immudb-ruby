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
  class Tx
    attr_accessor :header, :entries, :htree

    def initialize
      @header = nil
      @entries = nil
      @htree = nil
    end

    def tx_entry_digest
      if @header.version == 0
        method(:tx_entry_digest_v1_1)
      elsif @header.version == 1
        method(:tx_entry_digest_v1_2)
      else
        raise VerificationError
      end
    end

    def build_hash_tree
      digests = []
      tx_entry_digest = self.tx_entry_digest
      @entries.each do |e|
        digests << tx_entry_digest.call(e)
      end
      @htree.build_with(digests)
      root = @htree.root
      @header.eh = root
    end

    def index_of(key)
      kindex = nil
      @entries.each_with_index do |v, k|
        if v.key == key
          kindex = k
          break
        end
      end
      if kindex.nil?
        raise VerificationError
      end
      kindex
    end

    def proof(key)
      kindex = index_of(key)
      htree.inclusion_proof(kindex)
    end

    private

    def tx_entry_digest_v1_1(e)
      unless e.md.nil?
        # TODO raise ErrMetadataUnsupported
        raise VerificationError
      end
      md = Digest::SHA256.new
      md.update(e.k)
      md.update(e.hVal)
      md.digest
    end

    def tx_entry_digest_v1_2(e)
      mdbs = "".b
      if !e.md.nil?
        raise "Not supported yet"
        # mdbs = e.md.Bytes()
      end
      mdLen = mdbs.length
      b = "".b
      b = b + [mdLen].pack("n")
      b = b + mdbs
      b = b + [e.kLen].pack("n")
      b = b + e.k
      md = Digest::SHA256.new
      md.update(b)
      md.update(e.hVal)
      md.digest
    end
  end
end
