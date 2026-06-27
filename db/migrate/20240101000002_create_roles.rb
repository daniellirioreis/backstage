class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :roles, :name, unique: true

    add_foreign_key :users, :roles
  end
end
