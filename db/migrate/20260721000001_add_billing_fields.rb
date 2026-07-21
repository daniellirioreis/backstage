class AddBillingFields < ActiveRecord::Migration[7.1]
  def change
    # Preço mensal do plano
    add_column :plans, :price, :decimal, precision: 10, scale: 2, default: 0.0, null: false

    # Campos Asaas na empresa
    add_column :companies, :asaas_customer_id,      :string
    add_column :companies, :asaas_subscription_id,  :string
    add_column :companies, :subscription_status,     :string, default: "inactive"
    add_column :companies, :subscription_expires_at, :datetime

    add_index :companies, :asaas_customer_id,     unique: true, where: "asaas_customer_id IS NOT NULL"
    add_index :companies, :asaas_subscription_id, unique: true, where: "asaas_subscription_id IS NOT NULL"
  end
end
