class AddLayoutToBadgeConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :badge_configs, :layout, :string, default: "classic", null: false
  end
end
