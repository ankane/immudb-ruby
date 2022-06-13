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
  class HTree
    attr_reader :root

    def initialize(max_width)
      return if max_width < 1

      @max_width = max_width
      lw = 1
      while lw < max_width
        lw = lw << 1
      end
      height = (max_width - 1).bit_length + 1
      @levels = [nil] * height
      height.times do |l|
        @levels[l] = [nil] * (lw >> l)
      end
    end

    def build_with(digests)
      if digests.length > @max_width
        raise ArgumentError, "Max width exceeded"
      end
      if digests.length == 0
        raise ArgumentError, "Illegal arguments"
      end
      digests.length.times do |i|
        leaf = LEAF_PREFIX + digests[i]
        @levels[0][i] = Digest::SHA256.digest(leaf)
      end
      l = 0
      w = digests.length
      while w > 1
        wn = 0
        i = 0
        while i + 1 < w
          b = NODE_PREFIX + @levels[l][i] + @levels[l][i + 1]
          @levels[l + 1][wn] = Digest::SHA256.digest(b)
          wn = wn + 1
          i = i + 2
        end
        if w % 2 == 1
          @levels[l + 1][wn] = @levels[l][w - 1]
          wn = wn + 1
        end
        l += 1
        w = wn
      end
      @width = digests.length
      @root = @levels[l][0]
    end

    def inclusion_proof(i)
      if i >= @width
        raise ArgumentError, "Illegal arguments"
      end
      m = i
      n = @width
      offset = 0
      proof = InclusionProof.new
      proof.leaf = i
      proof.width = @width
      if @width == 1
        return proof
      end
      loop do
        d = (n - 1).bit_length
        k = 1 << (d - 1)
        if m < k
          l, r = offset + k, offset + n - 1
          n = k
        else
          l, r = offset, offset + k - 1
          m = m - k
          n = n - k
          offset = offset + k
        end
        layer = (r - l).bit_length
        index = (l / (1 << layer)).to_i
        proof.terms = @levels[layer][index] + proof.terms
        if n < 1 || (n == 1 && m == 0)
          return proof
        end
      end
    end
  end
end
