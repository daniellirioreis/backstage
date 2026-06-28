class AddNameTeamColorsToBadgeConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :badge_configs, :name_color,      :string, default: "#18181b"
    add_column :badge_configs, :team_info_color, :string, default: "#52525b"
  end
end
