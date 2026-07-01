class RenameFechamentoPermissionToClosing < ActiveRecord::Migration[7.1]
  def up
    Permission.where(resource: "reports", action: "fechamento").update_all(action: "closing")
  end

  def down
    Permission.where(resource: "reports", action: "closing").update_all(action: "fechamento")
  end
end
