module ApplicationHelper
  def event_status_badge(event)
    case event.status
    when "draft"   then "bg-secondary"
    when "active"  then "bg-success"
    when "closed"  then "bg-dark"
    end
  end

  def badge_qr_svg(content, pixel_size: 48)
    qr = RQRCode::QRCode.new(content.to_s)
    modules = qr.modules.size
    mod_px  = (pixel_size.to_f / modules).ceil
    actual  = mod_px * modules

    svg = %(<svg width="#{actual}" height="#{actual}" viewBox="0 0 #{actual} #{actual}" xmlns="http://www.w3.org/2000/svg" style="display:block;">)
    svg << %(<rect width="#{actual}" height="#{actual}" fill="#0d0d0d"/>)
    qr.modules.each_with_index do |row, r|
      row.each_with_index do |dark, c|
        if dark
          x = c * mod_px
          y = r * mod_px
          svg << %(<rect x="#{x}" y="#{y}" width="#{mod_px}" height="#{mod_px}" fill="#4ade80"/>)
        end
      end
    end
    svg << "</svg>"
    svg.html_safe
  end
end
