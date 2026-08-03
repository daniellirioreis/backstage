class CreateDailyCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :daily_credentials do |t|
      t.references :team_membership, null: false, foreign_key: true
      t.date   :date,            null: false
      t.string :credential_code, null: false

      t.timestamps
    end

    add_index :daily_credentials, :credential_code, unique: true
    add_index :daily_credentials, [:team_membership_id, :date], unique: true
  end
end
