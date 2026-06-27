module ApplicationHelper
  def event_status_badge(event)
    case event.status
    when "draft"   then "bg-secondary"
    when "active"  then "bg-success"
    when "closed"  then "bg-dark"
    end
  end
end
