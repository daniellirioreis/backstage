class CreateSectorFunctions < ActiveRecord::Migration[7.1]
  def change
    create_table :sector_functions do |t|
      t.references :sector,         null: false, foreign_key: true
      t.references :event_function, null: false, foreign_key: true
      t.integer    :quantity,       null: false, default: 1
      t.timestamps
    end
    add_index :sector_functions, [:sector_id, :event_function_id], unique: true
  end
end
