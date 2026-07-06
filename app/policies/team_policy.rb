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

  # Credenciais: só com evento ativo
  def credentials? = can?("show") && (user.admin? || event_active?)

  # Gestão de membros com evento ativo
  def manage_members?   = user.admin? || (event_active? && can?("manage_members"))

  # Cadastro rápido de substituto com evento ativo
  def quick_add_member? = user.admin? || (event_active? && can?("quick_add_member"))

  # Painel operacional do coordenador
  def panel?
    return true if user.admin?
    return false unless can?("panel")
    # Coordenador só vê o painel da equipe que ele coordena
    user.admin? || record.team_memberships.exists?(user_id: user.id, role: :coordinator)
  end

  private

  def resource_name = "teams"

  def active_member_management?
    event_active? && can?("manage_members")
  end
end
