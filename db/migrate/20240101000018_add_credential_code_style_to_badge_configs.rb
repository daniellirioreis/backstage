class AddCredentialCodeStyleToBadgeConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :badge_configs, :credential_code_font_size, :integer, default: 8
    add_column :badge_configs, :credential_code_color,     :string,  default: "#a1a1aa"
  end
end
