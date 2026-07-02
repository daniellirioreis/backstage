class RemoveExpectedHeadcountFromSectors < ActiveRecord::Migration[7.1]
  def change
    remove_column :sectors, :expected_headcount, :integer
  end
end
