class CreateEventDays < ActiveRecord::Migration[7.1]
  def change
    create_table :event_days do |t|
      t.references :event, null: false, foreign_key: true
      t.date    :date,  null: false
      t.decimal :hours, null: false, precision: 4, scale: 1, default: 8.0

      t.timestamps
    end

    add_index :event_days, [:event_id, :date], unique: true
  end
end
