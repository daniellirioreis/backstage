class BackstagePaginationRenderer < WillPaginate::ActionView::LinkRenderer
  protected

  def html_container(html)
    tag(:nav, html, style: "display:flex; gap:0.4rem; align-items:center;")
  end

  def page_number(page)
    current = page == current_page
    style = base_style
    style += " background:#18181b; color:#fff; border-color:#18181b;" if current
    tag(:a, page.to_s, href: url(page), style: style)
  end

  def previous_or_next_page(page, text, classname, rel = nil)
    disabled = page.nil?
    style = base_style
    style += " color:#a1a1aa; cursor:default; pointer-events:none;" if disabled
    if disabled
      tag(:span, text, style: style)
    else
      tag(:a, text, href: url(page), style: style)
    end
  end

  def gap
    tag(:span, "…", style: "padding:0 4px; color:#a1a1aa; font-size:0.85rem;")
  end

  private

  def base_style
    "display:inline-flex; align-items:center; justify-content:center; " \
    "min-width:2rem; height:2rem; padding:0 0.5rem; " \
    "border:1px solid #e4e4e7; border-radius:6px; " \
    "font-size:0.8rem; font-weight:500; color:#18181b; " \
    "text-decoration:none; background:#fff;"
  end
end
