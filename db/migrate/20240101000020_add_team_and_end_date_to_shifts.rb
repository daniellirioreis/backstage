class AddTeamAndEndDateToShifts < ActiveRecord::Migration[7.1]
  def change
    add_reference :shifts, :team, null: true, foreign_key: true
    add_column    :shifts, :end_date, :date
  end
end
