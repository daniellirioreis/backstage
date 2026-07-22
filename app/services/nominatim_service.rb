class NominatimService
  BASE_URL = "https://nominatim.openstreetmap.org/search"

  # Tenta o endereço completo; se não encontrar, tenta só a parte após a última vírgula
  def self.geocode(address)
    return nil if address.blank?

    result = search(address)
    return result if result

    # Fallback: tenta a cidade/estado (última parte após vírgula)
    parts = address.split(",").map(&:strip)
    parts.length > 1 ? search(parts.last(2).join(", ")) : nil
  end

  def self.search(query)
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(
      q:            query,
      format:       "json",
      limit:        1,
      countrycodes: "br"
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Backstage/1.0 (daniellirioreis@gmail.com)"
    request["Accept"]     = "application/json"

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    results = JSON.parse(response.body)
    return nil if results.empty?

    { lat: results.first["lat"].to_f, lon: results.first["lon"].to_f }
  rescue StandardError
    nil
  end

  private_class_method :search
end
