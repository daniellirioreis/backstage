class AddEventTypeToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :event_type, :string
  end
end
