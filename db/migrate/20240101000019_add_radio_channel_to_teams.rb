class AddRadioChannelToTeams < ActiveRecord::Migration[7.1]
  def change
    add_column :teams, :radio_channel, :string
  end
end
