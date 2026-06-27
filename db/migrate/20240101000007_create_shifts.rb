class CreateShifts < ActiveRecord::Migration[7.1]
  def change
    create_table :shifts do |t|
      t.date    :date, null: false
      t.time    :start_time, null: false
      t.time    :end_time, null: false
      t.boolean :has_radio, null: false, default: false
      t.references :user,   null: false, foreign_key: true
      t.references :sector, null: false, foreign_key: true

      t.timestamps
    end

    add_index :shifts, [ :user_id, :date ]
  end
end
