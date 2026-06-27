class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user   = user
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
    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve
      @scope.all
    end

    private

    attr_reader :user, :scope
  end

  private

  def resource_name
    record.class == Class ? record.name.underscore.pluralize : record.class.name.underscore.pluralize
  end

  def can?(action)
    user.present? && (user.admin? || user.can?(resource_name, action))
  end
end
