class AddWaivedToPayments < ActiveRecord::Migration[7.1]
  def change
    add_column :payments, :waived, :boolean, default: false, null: false
    add_column :payments, :waived_reason, :string
  end
end
