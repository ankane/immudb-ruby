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
  LEAF_PREFIX = "\x00".b
  NODE_PREFIX = "\x01".b
  ROOT_CACHE_PATH = ".immudbRoot"

  PERMISSION = {
    sys_admin: 255,
    admin: 254,
    none: 0,
    read: 1,
    read_write: 2
  }

  SET_KEY_PREFIX = "\x00".b
  SORTED_KEY_PREFIX = "\x01".b

  PLAIN_VALUE_PREFIX = "\x00".b
  REFERENCE_VALUE_PREFIX = "\x01".b

  OLDEST_FIRST = false
  NEWEST_FIRST = true
end
