class AddCredentialCodes < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :code, :string
    add_column :team_memberships, :credential_code, :string
    add_column :teams, :coordinator_credential_code, :string

    add_index :team_memberships, :credential_code, unique: true
    add_index :teams, :coordinator_credential_code, unique: true
  end
end
