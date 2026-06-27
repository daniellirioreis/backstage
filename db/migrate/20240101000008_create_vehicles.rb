class CreateVehicles < ActiveRecord::Migration[7.1]
  def change
    create_table :vehicles do |t|
      t.string :model, null: false
      t.string :color
      t.string :license_plate, null: false

      t.timestamps
    end

    add_index :vehicles, :license_plate, unique: true
  end
end
