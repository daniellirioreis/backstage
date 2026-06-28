class CreateAttendances < ActiveRecord::Migration[7.1]
  def change
    create_table :attendances do |t|
      t.references :user,           null: false, foreign_key: true
      t.references :event,          null: false, foreign_key: true
      t.references :team,           null: true,  foreign_key: true
      t.references :checked_in_by,  null: true,  foreign_key: { to_table: :users }
      t.datetime   :checked_in_at,  null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    add_index :attendances, [:user_id, :event_id], unique: true
  end
end
