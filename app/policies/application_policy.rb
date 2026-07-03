class ApplicationPolicy
  attr_reader :user, :record, :current_event

  def initialize(context, record)
    # Suporta tanto UserContext (com evento) quanto user direto (retrocompatibilidade)
    if context.respond_to?(:user)
      @user          = context.user
      @current_event = context.event
    else
      @user          = context
      @current_event = nil
    end
    @record = record
  end

  def index?   = can?("index")
  def show?    = can?("show")
  def new?     = can?("create")
  def create?  = can?("create")
  def edit?    = can?("update")
  def update?  = can?("update")
  def destroy? = can?("destroy")

  class Scope
    def initialize(context, scope)
      if context.respond_to?(:user)
        @user  = context.user
        @event = context.event
      else
        @user  = context
        @event = nil
      end
      @scope = scope
    end

    def resolve
      @scope.all
    end

    private

    attr_reader :user, :scope, :event
  end

  private

  def resource_name
    record.class == Class ? record.name.underscore.pluralize : record.class.name.underscore.pluralize
  end

  def can?(action)
    user.present? && (user.admin? || user.can?(resource_name, action))
  end

  # Status do evento atual (via contexto ou derivado do record)
  def event_status
    ev = current_event || derived_event
    ev&.status
  end

  def event_draft?  = event_status == "draft"
  def event_active? = event_status == "active"
  def event_closed? = event_status == "closed"

  # Tenta derivar o evento a partir do record (para policies sem contexto explícito)
  def derived_event
    case record
    when Event              then record
    when Sector             then record.event
    when Team               then record.sector&.event
    when Shift              then record.sector&.event
    when Attendance         then record.event
    when EventFunction      then record.event
    when BadgeConfig        then record.event
    when TeamMembership     then record.team&.sector&.event
    end
  rescue
    nil
  end
end
