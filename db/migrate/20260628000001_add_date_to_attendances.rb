class AddDateToAttendances < ActiveRecord::Migration[7.1]
  def change
    add_column :attendances, :checked_in_date, :date

    # Preenche registros existentes com a data do checked_in_at
    reversible do |dir|
      dir.up { execute "UPDATE attendances SET checked_in_date = DATE(checked_in_at)" }
    end

    change_column_null :attendances, :checked_in_date, false

    # Remove índice único anterior (por evento) e cria por evento+dia
    remove_index :attendances, [:user_id, :event_id]
    add_index    :attendances, [:user_id, :event_id, :checked_in_date], unique: true, name: "index_attendances_unique_per_day"
  end
end
