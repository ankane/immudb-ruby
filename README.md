# immudb-ruby

Ruby client for [immudb](https://github.com/codenotary/immudb)

[![Build Status](https://github.com/ankane/immudb-ruby/workflows/build/badge.svg?branch=master)](https://github.com/ankane/immudb-ruby/actions)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem "immudb"
```

## Getting Started

Create a client

```ruby
immudb = Immudb::Client.new
```

All of these options are supported

```ruby
Immudb::Client.new(
  host: "localhost",
  port: 3322,
  username: "immudb",
  password: "immudb",
  database: "defaultdb",
  timeout: nil
)
```

You can also use a URL. Set `ENV["IMMUDB_URL"]` or use:

```ruby
Immudb::Client.new(url: "immudb://user:pass@host:port/dbname")
```

### Keys

Set and get keys

```ruby
immudb.set("hello", "world")
immudb.get("hello")
```

Set and get keys with verification

```ruby
immudb.verified_set("hello", "world")
immudb.verified_get("hello")
```

Set and get multiple keys

```ruby
immudb.set_all({"a" => "one", "b" => "two"})
immudb.get_all(["a", "b"])
```

Get the history of a key

```ruby
immudb.history("key")
```

Iterate over keys

```ruby
immudb.scan
```

### SQL

List tables

```ruby
immudb.list_tables
```

Create a table

```ruby
immudb.sql_exec("CREATE TABLE cities (id INTEGER, name VARCHAR, PRIMARY KEY id)")
```

Describe a table

```ruby
immudb.describe_table("cities")
```

Execute a statement

```ruby
immudb.sql_exec("INSERT INTO cities (id, name) VALUES (@id, @name)", {id: 1, name: "Chicago"})
```

Query data

```ruby
immudb.sql_query("SELECT * FROM cities WHERE id = @id", {id: 1}).to_a
```

See the [SQL Reference](https://docs.immudb.io/master/reference/sql.html) for more info

### Databases

List databases

```ruby
immudb.list_databases
```

Create a database

```ruby
immudb.create_database("dbname")
```

Change the database

```ruby
immudb.use_database("dbname")
```

### Users

List users

```ruby
immudb.list_users
```

Create a user

```ruby
immudb.create_user("user", password: "P@ssw0rd", permission: :read_write, database: "dbname")
```

Permission can be `:read`, `:read_write`, or `:admin`

Change password

```ruby
immudb.change_password("user", old_password: "P@ssw0rd", new_password: "P@ssw0rd2")
```

### Other

Check health

```ruby
immudb.healthy?
```

Clean indexes

```ruby
immudb.clean_index
```

## History

View the [changelog](https://github.com/ankane/immudb-ruby/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/immudb-ruby/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/immudb-ruby/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development:

```sh
git clone https://github.com/ankane/immudb-ruby.git
cd immudb-ruby
bundle install
bundle exec rake test
```
