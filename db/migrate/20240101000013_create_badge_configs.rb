class CreateBadgeConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :badge_configs do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :photo_size,           default: 115
      t.integer :name_font_size,       default: 20
      t.integer :role_chip_font_size,  default: 13
      t.integer :team_info_font_size,  default: 12
      t.integer :event_name_font_size, default: 14
      t.integer :event_date_font_size, default: 6
      t.timestamps
    end
  end
end
