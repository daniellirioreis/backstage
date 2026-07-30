class AddReplacedUserIdToTeamMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :team_memberships, :replaced_user_id, :integer
    add_index  :team_memberships, :replaced_user_id
  end
end
