class ReportPolicy < ApplicationPolicy
  # Fechamento: só com evento encerrado
  def closing? = can?("closing") && (user.admin? || event_closed?)

  # Pagamentos: registrar e desfazer — exige evento encerrado
  def manage_payments? = can?("manage_payments") && (user.admin? || event_closed?)

  # Comprovante: visualizar/baixar PDF — acesso mais amplo (quem pode ver fechamento pode ver comprovante)
  def view_receipt? = can?("closing") && (user.admin? || event_closed?)

  # Finalizar fechamento: admin ou quem tem permissão específica
  def finalize_closing? = (user.admin? || can?("finalize_closing")) && event_closed?

  # Reabrir fechamento: admin ou quem tem permissão específica
  def reopen_closing? = (user.admin? || can?("reopen_closing")) && event_closed?

  # Relatórios operacionais — disponíveis para qualquer status de evento
  def attendance_report?    = user.admin? || can?("attendance_report")
  def absences_report?      = user.admin? || can?("absences_report")
  def hours_worked_report?  = user.admin? || can?("hours_worked_report")
  def sector_summary_report? = user.admin? || can?("sector_summary_report")

  private

  def resource_name = "reports"
end
