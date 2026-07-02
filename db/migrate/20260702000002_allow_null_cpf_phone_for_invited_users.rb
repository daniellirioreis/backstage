class AllowNullCpfPhoneForInvitedUsers < ActiveRecord::Migration[7.1]
  def change
    change_column_null :users, :cpf,   true
    change_column_null :users, :phone, true
  end
end
