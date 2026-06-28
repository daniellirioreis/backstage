class BadgeConfigsController < ApplicationController
  before_action :set_event
  before_action :set_badge_config

  def edit
    authorize @badge_config
  end

  def update
    authorize @badge_config
    @badge_config.assign_attributes(badge_config_params)
    if @badge_config.save
      redirect_to edit_event_badge_config_path(@event), notice: t("badge_config.saved")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_badge_config
    @badge_config = @event.badge_config || @event.build_badge_config(
      photo_size: 115, name_font_size: 20, role_chip_font_size: 13,
      team_info_font_size: 12, event_name_font_size: 14, event_date_font_size: 6,
      event_name_color: "#4ade80", header_footer_color: "#0d0d0d", body_color: "#f5f5f4",
      name_color: "#18181b", team_info_color: "#52525b",
      credential_code_font_size: 8, credential_code_color: "#a1a1aa"
    )
  end

  def badge_config_params
    params.require(:badge_config).permit(
      :photo_size, :name_font_size, :role_chip_font_size,
      :team_info_font_size, :event_name_font_size, :event_date_font_size,
      :event_name_color, :header_footer_color, :body_color, :name_color, :team_info_color,
      :credential_code_font_size, :credential_code_color
    )
  end
end
