class CreatePermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :permissions do |t|
      t.references :role, null: false, foreign_key: true
      t.string :resource, null: false
      t.string :action, null: false

      t.timestamps
    end

    add_index :permissions, [ :role_id, :resource, :action ], unique: true
  end
end
