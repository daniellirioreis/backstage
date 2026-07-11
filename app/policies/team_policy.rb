class TeamPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  # Estrutural: só no rascunho
  def create?  = can?("create")  && (user.admin? || event_draft?)
  def destroy? = can?("destroy") && (user.admin? || event_draft?)

  # Edição estrutural: só no rascunho
  def edit?   = can?("update") && (user.admin? || event_draft?)
  def update? = can?("update") && (user.admin? || event_draft?)

  # Credenciais: disponível em rascunho e ativo
  def credentials? = can?("show")

  # Gestão de membros: adicionar/importar colaboradores (qualquer status de evento)
  def manage_members? = user.admin? || can?("manage_members")

  # Cadastro rápido de substituto — delega a manage_members (evento ativo preferencial,
  # mas a permissão em si já está em manage_members)
  def quick_add_member? = manage_members?

  # Painel operacional do coordenador
  def panel?
    return true if user.admin?
    can?("panel") && record.coordinator_id == user.id
  end

  def coordinator?
    user.admin? || (can?("coordinator") && Team.exists?(coordinator_id: user.id))
  end

  private

  def resource_name = "teams"
end
