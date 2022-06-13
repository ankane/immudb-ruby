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
  class TxHeader
    attr_accessor :iD, :ts, :blTxID, :blRoot, :prevAlh, :version, :metadata, :nentries, :eh

    def initialize
      @iD = nil
      @ts = nil
      @blTxID = nil
      @blRoot = nil
      @prevAlh = nil

      @version = nil
      @metadata = TxMetadata.new

      @nentries = nil
      @eh = nil
    end

    def inner_hash
      md = Digest::SHA256.new
      md.update([@ts].pack("Q>"))
      md.update([@version].pack("n"))
      if @version == 0
        md.update([@nentries].pack("n"))
      elsif @version == 1
        mdbs = "".b
        if !@metadata.nil?
          mdbs = @metadata.Bytes()
          if mdbs.nil?
            mdbs = "".b
          end
        end
        md.update([mdbs.length].pack("n"))
        md.update(mdbs)
        md.update([@nentries].pack("N"))
      else
        raise VerificationError, "missing tx hash calculation method for version #{@version}"
      end
      md.update(@eh)
      md.update([@blTxID].pack("Q>"))
      md.update(@blRoot)
      md.digest
    end

    def alh
      md = Digest::SHA256.new
      md.update([@iD].pack("Q>"))
      md.update(@prevAlh)
      md.update(inner_hash)
      md.digest
    end
  end
end
