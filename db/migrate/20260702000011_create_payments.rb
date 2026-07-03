class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :event,   null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.references :paid_by, null: false, foreign_key: { to_table: :users }

      t.decimal :amount,       precision: 10, scale: 2, null: false
      t.decimal :hours,        precision: 8,  scale: 2
      t.decimal :hourly_rate,  precision: 10, scale: 2
      t.string  :function_name
      t.string  :method,  null: false, default: "pix"
      t.string  :basis,   null: false, default: "shifts"
      t.text    :notes
      t.datetime :paid_at, null: false

      t.timestamps
    end

    # Um pagamento por colaborador por evento por base de cálculo
    add_index :payments, [:event_id, :user_id, :basis], unique: true
  end
end
