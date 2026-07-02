class AddSectorTypeToSectors < ActiveRecord::Migration[7.1]
  def change
    add_column :sectors, :sector_type, :string
    add_index  :sectors, :sector_type
  end
end
