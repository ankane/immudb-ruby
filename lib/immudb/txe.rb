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
  class TXe
    attr_accessor :key_len, :key, :value_len, :h_value, :v_off

    def set_key(key)
      @key = key.dup
      @key_len = key.length
    end

    def digest
      b = @key + @h_value
      Digest::SHA256.digest(b)
    end
  end
end
