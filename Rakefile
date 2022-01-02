require "bundler/gem_tasks"
require "rake/testtask"

task default: :test
Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.warning = false # for grpc gem
end

task :generate do
  system "grpc_tools_ruby_protoc -I grpc --ruby_out=lib/immudb/grpc --grpc_out=lib/immudb/grpc grpc/schema.proto"
  Dir["lib/immudb/grpc/*_pb.rb"].each do |file|
    contents = File.read(file)
    # remove relative *_pb requires
    File.write(file, contents.gsub(/require '\w+_pb'\n/m, ""))
  end
end
