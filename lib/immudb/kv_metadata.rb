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
  class KVMetadata
    DELETED_ATTR_CODE = 0
    EXPIRES_AT_ATTR_CODE = 1
    NON_INDEXABLE_ATTR_CODE = 2

    def initialize
      @attributes = {}
      @readonly = false
    end

    def as_deleted(deleted)
      if @readonly
        raise Error, "Read-only"
      elsif !deleted
        @attributes.delete(DELETED_ATTR_CODE)
      else
        @attributes[DELETED_ATTR_CODE] = nil
      end
    end

    def deleted?
      @attributes.key?(DELETED_ATTR_CODE)
    end

    def expires_at(expires_at)
      if @readonly
        raise Error, "Read-only"
      end
      @attributes[EXPIRES_AT_ATTR_CODE] = expires_at
    end

    def non_expirable
      @attributes.delete(EXPIRES_AT_ATTR_CODE)
    end

    def expirable?
      @attributes.key?(EXPIRES_AT_ATTR_CODE)
    end

    def expiration_time
      if @attributes.key?(EXPIRES_AT_ATTR_CODE)
        @attributes[EXPIRES_AT_ATTR_CODE]
      else
        raise Error, "Non-expirable"
      end
    end

    def as_non_indexable(non_indexable)
      if @readonly
        raise Error, "Read-only"
      elsif !non_indexable
        @attributes.delete(NON_INDEXABLE_ATTR_CODE)
      else
        @attributes[NON_INDEXABLE_ATTR_CODE] = nil
      end
    end

    def non_indexable?
      @attributes.key?(NON_INDEXABLE_ATTR_CODE)
    end

    def bytes
      b = "".b
      [DELETED_ATTR_CODE, EXPIRES_AT_ATTR_CODE, NON_INDEXABLE_ATTR_CODE].each do |attr_code|
        if @attributes.key?(attr_code)
          b += [attr_code].pack("C")
          if attr_code == EXPIRES_AT_ATTR_CODE
            b += [@attributes[attr_code].to_i].pack("Q>")
          end
        end
      end
      b
    end
  end
end
