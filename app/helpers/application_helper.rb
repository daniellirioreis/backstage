module ApplicationHelper
  def timeline_colors
    %w[#378ADD #1D9E75 #D85A30 #7F77DD #BA7517 #993556 #185FA5 #3B6D11]
  end

  def timeline_minutes(t)
    t.hour * 60 + t.min
  end

  def timeline_bar_left(start_t)
    (timeline_minutes(start_t) / 1440.0 * 100).round(2)
  end

  def timeline_bar_width(start_t, end_t)
    s = timeline_minutes(start_t)
    e = timeline_minutes(end_t)
    duration = e > s ? e - s : (1440 - s) + e
    (duration / 1440.0 * 100).round(2)
  end

  # Converte horas decimais para "HH:MM"
  def format_hours(decimal_hours)
    total_min = (decimal_hours * 60).round
    h = total_min / 60
    m = total_min % 60
    format("%d:%02d", h, m)
  end

  def format_phone(phone)
    digits = phone.to_s.gsub(/\D/, "")
    case digits.length
    when 11 then "(#{digits[0,2]}) #{digits[2,5]}-#{digits[7,4]}"
    when 10 then "(#{digits[0,2]}) #{digits[2,4]}-#{digits[6,4]}"
    else phone
    end
  end

  def event_status_badge(event)
    case event.status
    when "draft"   then "bg-secondary"
    when "active"  then "bg-success"
    when "closed"  then "bg-dark"
    end
  end

  def badge_qr_svg(content, pixel_size: 48, color: "#4ade80", bg: "#0d0d0d")
    qr = RQRCode::QRCode.new(content.to_s)
    modules = qr.modules.size
    mod_px  = (pixel_size.to_f / modules).ceil
    actual  = mod_px * modules

    svg = %(<svg width="#{actual}" height="#{actual}" viewBox="0 0 #{actual} #{actual}" xmlns="http://www.w3.org/2000/svg" style="display:block;">)
    svg << %(<rect width="#{actual}" height="#{actual}" fill="#{bg}"/>)
    qr.modules.each_with_index do |row, r|
      row.each_with_index do |dark, c|
        if dark
          x = c * mod_px
          y = r * mod_px
          svg << %(<rect x="#{x}" y="#{y}" width="#{mod_px}" height="#{mod_px}" fill="#{color}"/>)
        end
      end
    end
    svg << "</svg>"
    svg.html_safe
  end
end
