class AddInvitationFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :invitation_token,       :string
    add_column :users, :invitation_accepted_at, :datetime
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :invited_by_id,          :bigint

    add_index :users, :invitation_token, unique: true
  end
end
