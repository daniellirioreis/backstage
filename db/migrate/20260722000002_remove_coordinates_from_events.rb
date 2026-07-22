class RemoveCoordinatesFromEvents < ActiveRecord::Migration[7.1]
  def change
    remove_column :events, :latitude,           :decimal
    remove_column :events, :longitude,          :decimal
    remove_column :events, :location_validated, :boolean
  end
end
