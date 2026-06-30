class AddCheckoutToAttendances < ActiveRecord::Migration[7.1]
  def change
    add_column :attendances, :checked_out_at, :datetime, null: true
    add_column :attendances, :checked_out_by_id, :bigint, null: true
    add_foreign_key :attendances, :users, column: :checked_out_by_id
  end
end
