class AddCoordinatesToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :latitude,           :decimal, precision: 10, scale: 7
    add_column :events, :longitude,          :decimal, precision: 10, scale: 7
    add_column :events, :location_validated, :boolean, default: false, null: false
  end
end
