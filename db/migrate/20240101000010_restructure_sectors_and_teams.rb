class RestructureSectorsAndTeams < ActiveRecord::Migration[7.1]
  def change
    # Adiciona event_id em sectors
    add_reference :sectors, :event, null: false, foreign_key: true, default: 0
    change_column_default :sectors, :event_id, from: 0, to: nil

    # Adiciona sector_id em teams
    add_reference :teams, :sector, null: false, foreign_key: true, default: 0
    change_column_default :teams, :sector_id, from: 0, to: nil

    # Remove event_id de teams
    remove_reference :teams, :event, foreign_key: true

    # Remove team_id de sectors
    remove_reference :sectors, :team, foreign_key: true
  end
end
