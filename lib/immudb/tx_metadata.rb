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
  class TxMetadata
    attr_accessor :iD, :prevAlh, :ts, :nEntries, :eh, :blTxID, :blRoot

    def alh
      bi = [@iD].pack("Q>") + @prevAlh
      bj = [@ts.to_i, @nEntries.to_i].pack("Q>L>")
      bj = bj + @eh + [@blTxID].pack("Q>") + @blRoot
      inner_hash = Digest::SHA256.digest(bj)
      bi = bi + inner_hash
      Digest::SHA256.digest(bi)
    end

    def bytes
      nil
    end
  end
end
