class AddClosingFinalizedToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :closing_finalized_at, :datetime
    add_column :events, :closing_finalized_by_id, :integer
    add_index  :events, :closing_finalized_by_id
  end
end
