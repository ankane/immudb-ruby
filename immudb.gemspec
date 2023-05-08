require_relative "lib/immudb/version"

Gem::Specification.new do |spec|
  spec.name          = "immudb"
  spec.version       = Immudb::VERSION
  spec.summary       = "Ruby client for immudb"
  spec.homepage      = "https://github.com/ankane/immudb-ruby"
  spec.license       = "Apache-2.0"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@ankane.org"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 3"

  spec.add_dependency "grpc"
end
