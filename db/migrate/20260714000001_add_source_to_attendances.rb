class AddSourceToAttendances < ActiveRecord::Migration[7.1]
  def change
    add_column :attendances, :source, :string, default: "qr_code", null: false
    add_index  :attendances, :source
  end
end
