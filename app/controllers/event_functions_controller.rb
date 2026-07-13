class EventFunctionsController < ApplicationController
  before_action :set_event, only: %i[index create update destroy add_from_catalog]
  before_action :set_event_function, only: %i[edit update destroy]

  # GET /event_functions  (catálogo global)
  # GET /events/:event_id/event_functions  (funções do evento)
  def index
    sentinel = @event ? @event.event_functions.build : EventFunction.new
    authorize sentinel
    if @event
      @event_functions  = @event.event_functions.order(:name)
      @catalog_functions = EventFunction.catalog.order(:name).reject do |cf|
        @event_functions.any? { |ef| ef.name.downcase == cf.name.downcase }
      end
    else
      @q = params[:q].to_s.strip
      scope = EventFunction.catalog.order(:name)
      scope = scope.where("name ILIKE ?", "%#{@q}%") if @q.present?
      @event_functions = scope.paginate(page: params[:page], per_page: 10)
    end
  end

  # GET /event_functions/new  (catálogo)
  def new
    @event_function = EventFunction.new
    authorize @event_function
  end

  # GET /event_functions/:id/edit  (catálogo)
  def edit
    authorize @event_function
  end

  # POST /event_functions  (catálogo)
  # POST /events/:event_id/event_functions  (evento)
  def create
    sentinel = @event ? @event.event_functions.build : EventFunction.new
    authorize sentinel

    name        = params.dig(:event_function, :name)&.strip
    hourly_rate = params.dig(:event_function, :hourly_rate)

    if name.blank? || hourly_rate.blank?
      msg = "Informe nome e valor da função."
      return @event ? redirect_to(event_event_functions_path(@event), alert: msg)
                    : redirect_to(new_event_function_path, alert: msg)
    end

    if @event
      ef = @event.event_functions.build(name: name, hourly_rate: hourly_rate)
      if ef.save
        redirect_to event_event_functions_path(@event), notice: "Função \"#{ef.name}\" criada."
      else
        redirect_to event_event_functions_path(@event), alert: ef.errors.full_messages.to_sentence
      end
    else
      ef = EventFunction.new(name: name, hourly_rate: hourly_rate)
      if ef.save
        redirect_to event_functions_path, notice: "Função \"#{ef.name}\" adicionada ao catálogo."
      else
        @event_function = ef
        render :new, status: :unprocessable_entity
      end
    end
  end

  # PATCH /event_functions/:id  (catálogo)
  # PATCH /events/:event_id/event_functions/:id  (evento)
  def update
    authorize @event_function
    if @event_function.update(event_function_params)
      if @event
        redirect_to event_event_functions_path(@event), notice: "Função atualizada."
      else
        redirect_to event_functions_path, notice: "Função \"#{@event_function.name}\" atualizada."
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /event_functions/:id  (catálogo)
  # DELETE /events/:event_id/event_functions/:id  (evento)
  def destroy
    authorize @event_function
    name = @event_function.name
    @event_function.destroy
    if @event
      redirect_to event_event_functions_path(@event), notice: "Função \"#{name}\" removida."
    else
      redirect_to event_functions_path, notice: "Função \"#{name}\" removida do catálogo."
    end
  end

  # POST /events/:event_id/event_functions/add_from_catalog
  def add_from_catalog
    authorize @event.event_functions.build, :create?
    catalog_fn  = EventFunction.catalog.find(params[:catalog_id])
    hourly_rate = params.dig(:event_function, :hourly_rate).presence || catalog_fn.hourly_rate
    ef = @event.event_functions.build(name: catalog_fn.name, hourly_rate: hourly_rate)
    if ef.save
      redirect_to event_event_functions_path(@event), notice: "\"#{ef.name}\" adicionada ao evento."
    else
      redirect_to event_event_functions_path(@event), alert: ef.errors.full_messages.to_sentence
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id].present?
  end

  def set_event_function
    if @event
      @event_function = @event.event_functions.find(params[:id])
    else
      @event_function = EventFunction.find(params[:id])
    end
  end

  def event_function_params
    params.require(:event_function).permit(:name, :hourly_rate)
  end
end
