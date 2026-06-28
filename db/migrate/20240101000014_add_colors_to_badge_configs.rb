class AddColorsToBadgeConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :badge_configs, :event_name_color,     :string, default: "#4ade80"
    add_column :badge_configs, :header_footer_color,  :string, default: "#0d0d0d"
  end
end
