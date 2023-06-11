module Immudb
  module Client::UsersMethods
    def list_users
      permission_map = PERMISSION.invert
      grpc.list_users(Google::Protobuf::Empty.new).users.map do |user|
        {
          user: user.user,
          permissions: user.permissions.map { |v| { database: v.database, permission: permission_map.fetch(v.permission) } },
          created_by: user.createdby,
          created_at: Time.parse(user.createdat),
          active: user.active
        }
      end
    end

    def create_user(user, password:, permission:, database:)
      req = Schema::CreateUserRequest.new(user: user, password: password, permission: PERMISSION.fetch(permission), database: database)
      grpc.create_user(req)
      nil
    end

    def change_password(user, old_password:, new_password:)
      req = Schema::ChangePasswordRequest.new(user: user, oldPassword: old_password, newPassword: new_password)
      grpc.change_password(req)
      nil
    end
  end
end
