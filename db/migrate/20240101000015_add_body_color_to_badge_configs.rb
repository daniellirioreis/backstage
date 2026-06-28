class AddBodyColorToBadgeConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :badge_configs, :body_color, :string, default: "#f5f5f4"
  end
end
