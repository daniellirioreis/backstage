class AddEmpresaToEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :events, :empresa, null: true, foreign_key: true
  end
end
