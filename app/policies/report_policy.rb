class ReportPolicy < ApplicationPolicy
  # Fechamento: só com evento encerrado
  def closing? = can?("closing") && (user.admin? || event_closed?)

  # Pagamentos: registrar e desfazer — exige evento encerrado
  def manage_payments? = can?("manage_payments") && (user.admin? || event_closed?)

  # Comprovante: visualizar/baixar PDF — acesso mais amplo (quem pode ver fechamento pode ver comprovante)
  def view_receipt? = can?("closing") && (user.admin? || event_closed?)

  # Finalizar fechamento: admin ou quem tem permissão específica
  def finalize_closing? = (user.admin? || can?("finalize_closing")) && event_closed?

  # Reabrir fechamento: somente admin
  def reopen_closing? = user.admin? && event_closed?

  private

  def resource_name = "reports"
end
