class OnboardingController < ApplicationController
  skip_before_action :require_current_event!
  layout "onboarding"

  before_action :ensure_pending_onboarding

  # GET /onboarding/empresa
  def empresa
    return redirect_to onboarding_evento_path if current_user.companies.exists?
    @company = Company.new
  end

  # POST /onboarding/empresa
  def save_empresa
    return redirect_to onboarding_plano_path if current_user.companies.exists?

    @company = Company.new(company_params)
    if @company.save
      current_user.company_users.create!(company: @company, role: "owner")
      redirect_to onboarding_plano_path
    else
      render :empresa, status: :unprocessable_entity
    end
  end

  # GET /onboarding/plano
  def plano
    @company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless @company
    redirect_to onboarding_evento_path if @company.events.exists?
    @plans = Plan.order(:name)
  end

  # POST /onboarding/plano
  def save_plano
    @company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless @company

    plan_id = params[:plan_id].presence
    unless plan_id
      @plans = Plan.order(:name)
      flash.now[:alert] = "Selecione um plano para continuar."
      render :plano, status: :unprocessable_entity and return
    end

    @company.update!(plan_id: plan_id)
    redirect_to onboarding_evento_path
  end

  # GET /onboarding/evento
  def evento
    company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless company
    if company.events.exists?
      current_user.update_column(:onboarding_completed_at, Time.current)
      return redirect_to onboarding_done_path
    end
    @event = Event.new(company: company, start_date: Date.today, end_date: Date.today + 1)
  end

  # POST /onboarding/evento
  def save_evento
    company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless company

    # Se a empresa já tem eventos, pula a criação
    if company.events.exists?
      current_user.update_column(:onboarding_completed_at, Time.current)
      return redirect_to onboarding_done_path
    end

    @event = company.events.new(event_params)
    if @event.save
      session[:current_event_id] = @event.id
      current_user.update_column(:onboarding_completed_at, Time.current)
      redirect_to onboarding_done_path
    else
      @preset_events = []
      render :evento, status: :unprocessable_entity
    end
  end

  # POST /onboarding/evento/pular
  def skip_evento
    current_user.update_column(:onboarding_completed_at, Time.current)
    redirect_to onboarding_done_path
  end

  # GET /onboarding/concluido
  def done
    current_user.update_column(:onboarding_completed_at, Time.current) unless current_user.onboarding_complete?
  end

  private

  def ensure_pending_onboarding
    return if current_user.invitation_token.present? && current_user.invitation_accepted_at.present?
    redirect_to root_path
  end

  def company_params
    params.require(:company).permit(:name, :cnpj, :phone, :email, :city, :state, :plan_id)
  end

  def event_params
    params.require(:event).permit(:name, :location, :start_date, :end_date)
  end
end
