class CreateEmpresas < ActiveRecord::Migration[7.1]
  def change
    create_table :empresas do |t|
      t.string :name,          null: false
      t.string :cnpj
      t.string :phone
      t.string :email
      t.string :address
      t.string :city
      t.string :state
      t.string :primary_color, default: "#18181b"
      t.timestamps
    end
  end
end
