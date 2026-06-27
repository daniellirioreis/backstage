class AddCoordinatorToTeams < ActiveRecord::Migration[7.1]
  def change
    add_reference :teams, :coordinator, foreign_key: { to_table: :users }, null: true
  end
end
