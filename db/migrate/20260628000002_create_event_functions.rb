class CreateEventFunctions < ActiveRecord::Migration[7.1]
  def change
    create_table :event_functions do |t|
      t.references :event, null: false, foreign_key: true
      t.string     :name,        null: false
      t.decimal    :hourly_rate, precision: 8, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_index :event_functions, [:event_id, :name], unique: true

    add_reference :team_memberships, :event_function, foreign_key: { to_table: :event_functions }, null: true
  end
end
