class CreateEmpresaUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :empresa_users do |t|
      t.references :empresa, null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.string     :role,    null: false, default: "operator"
      t.timestamps
    end

    add_index :empresa_users, [:empresa_id, :user_id], unique: true
  end
end
