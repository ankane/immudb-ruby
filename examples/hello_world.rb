require "immudb"

immudb = Immudb::Client.new

key = "Hello"
value = "Immutable World!"

# set a key/value pair
immudb.set(key, value)

# reads back the value
saved_value = immudb.get(key)
puts "Hello #{saved_value}"
