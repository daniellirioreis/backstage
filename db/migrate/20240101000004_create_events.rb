class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.string :name, null: false
      t.string :location
      t.date   :start_date, null: false
      t.date   :end_date, null: false
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
  end
end
