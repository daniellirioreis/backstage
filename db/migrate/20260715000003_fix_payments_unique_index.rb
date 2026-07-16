class FixPaymentsUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    # Remove o índice antigo (event_id + user_id sem date) pelo nome exato
    remove_index :payments, name: "index_payments_on_event_id_and_user_id", if_exists: true
    remove_index :payments, name: "index_payments_on_user_id_and_event_id", if_exists: true

    # Garante que o índice com date existe
    unless index_exists?(:payments, [:user_id, :event_id, :date])
      add_index :payments, [:user_id, :event_id, :date], unique: true
    end
  end
end
