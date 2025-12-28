require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.pattern = "test/**/*_test.rb"
  t.warning = false # for grpc gem
end

task default: :test

task :generate do
  system "grpc_tools_ruby_protoc -I grpc --ruby_out=lib/immudb/grpc --grpc_out=lib/immudb/grpc grpc/schema.proto"

  # use require_relative
  # https://github.com/grpc/grpc/issues/6164
  Dir["lib/immudb/grpc/*_pb.rb"].each do |file|
    File.write(file, File.read(file).gsub(/require '(\w+)_pb'/, "require_relative '\\1_pb'"))
  end
end
