class AddDateToPayments < ActiveRecord::Migration[7.1]
  def change
    add_column :payments, :date, :date

    # Remove old unique index (user_id + event_id)
    remove_index :payments, [:user_id, :event_id], if_exists: true

    # Add new unique index scoped by date
    add_index :payments, [:user_id, :event_id, :date], unique: true
  end
end
