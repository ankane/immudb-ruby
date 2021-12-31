require_relative "test_helper"

class UserTest < Minitest::Test
  def test_works
    user = random_user
    assert_nil immudb.create_user(user, password: "P@ssw0rd", permission: :read, database: "testdb")
    assert_includes immudb.list_users.map { |v| v[:user] }, user
    assert_nil immudb.change_password(user, old_password: "P@ssw0rd", new_password: "P@ssw0rd2")
  end
end
