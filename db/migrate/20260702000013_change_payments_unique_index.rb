class ChangePaymentsUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index :payments, [:event_id, :user_id, :basis]
    add_index    :payments, [:event_id, :user_id], unique: true
  end
end
