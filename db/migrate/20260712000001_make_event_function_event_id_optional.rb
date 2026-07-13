class MakeEventFunctionEventIdOptional < ActiveRecord::Migration[7.1]
  def change
    # Remove índice único composto existente
    remove_index :event_functions, name: "index_event_functions_on_event_id_and_name"

    # Torna event_id opcional
    change_column_null :event_functions, :event_id, true

    # Índice único para funções de evento (event_id NOT NULL — mesmo comportamento de antes)
    add_index :event_functions, [:event_id, :name], unique: true,
              where: "event_id IS NOT NULL",
              name: "index_event_functions_on_event_id_and_name"

    # Índice único para funções de catálogo (event_id IS NULL)
    add_index :event_functions, :name, unique: true,
              where: "event_id IS NULL",
              name: "index_event_functions_catalog_name"
  end
end
