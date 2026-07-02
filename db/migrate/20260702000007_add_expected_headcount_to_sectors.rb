class AddExpectedHeadcountToSectors < ActiveRecord::Migration[7.1]
  def change
    add_column :sectors, :expected_headcount, :integer
  end
end
