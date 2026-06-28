class RemoveHasRadioFromShifts < ActiveRecord::Migration[7.1]
  def change
    remove_column :shifts, :has_radio, :boolean
  end
end
