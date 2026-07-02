class OnboardingController < ApplicationController
  skip_before_action :require_current_event!
  layout "onboarding"

  before_action :ensure_pending_onboarding

  # GET /onboarding/empresa
  def empresa
    @company   = Company.new
    @companies = Company.order(:name)
  end

  # POST /onboarding/empresa
  def save_empresa
    if params[:company_id].present?
      company = Company.find(params[:company_id])
      current_user.company_users.find_or_create_by(company: company) { |cu| cu.role = "manager" }
      redirect_to onboarding_evento_path
    else
      @company = Company.new(company_params)
      if @company.save
        current_user.company_users.create!(company: @company, role: "owner")
        redirect_to onboarding_evento_path
      else
        @companies = Company.order(:name)
        render :empresa, status: :unprocessable_entity
      end
    end
  end

  # GET /onboarding/evento
  def evento
    company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless company
    @event   = Event.new(company: company, start_date: Date.today, end_date: Date.today + 1)
  end

  # POST /onboarding/evento
  def save_evento
    company = current_user.companies.first
    redirect_to onboarding_empresa_path and return unless company

    @event = company.events.new(event_params)
    if @event.save
      session[:current_event_id] = @event.id
      current_user.update_column(:onboarding_completed_at, Time.current)
      redirect_to onboarding_done_path
    else
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
    params.require(:company).permit(:name, :cnpj, :phone, :email, :city, :state)
  end

  def event_params
    params.require(:event).permit(:name, :location, :start_date, :end_date)
  end
end
