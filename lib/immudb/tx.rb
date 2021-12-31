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
  class Tx
    attr_accessor :ID, :Ts, :BlTxID, :BlRoot, :PrevAlh, :nentries, :entries, :htree, :Alh

    def build_hash_tree
      digests = []
      @entries.each do |e|
        digests << e.digest
      end
      @htree.build_with(digests)
    end

    def calc_alh
      calc_innerhash
      bi = [@ID].pack("Q>") + @PrevAlh + @InnerHash
      @Alh = Digest::SHA256.digest(bi)
    end

    def calc_innerhash
      bj = [@Ts, @nentries].pack("Q>L>") + eh
      bj += [@BlTxID].pack("Q>") + @BlRoot
      @InnerHash = Digest::SHA256.digest(bj)
    end

    def eh
      @htree.root
    end

    def proof(key)
      kindex = nil
      # find index of element holding given key
      @entries.each_with_index do |v, k|
        if v.key == key
          kindex = k
          break
        end
      end
      if kindex.nil?
        raise KeyError
      end
      @htree.inclusion_proof(kindex)
    end
  end
end
