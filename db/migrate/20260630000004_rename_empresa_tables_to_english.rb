class RenameEmpresaTablesToEnglish < ActiveRecord::Migration[7.1]
  def change
    rename_table :empresas,      :companies
    rename_table :empresa_users, :company_users

    # A coluna empresa_id em events e company_users continua com o mesmo nome
    # mas renomeamos para company_id para consistência
    rename_column :events,         :empresa_id, :company_id
    rename_column :company_users,  :empresa_id, :company_id
  end
end
