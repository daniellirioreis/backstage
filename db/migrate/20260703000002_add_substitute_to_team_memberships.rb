class AddSubstituteToTeamMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :team_memberships, :substitute, :boolean, default: false, null: false
  end
end
