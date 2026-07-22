class NominatimService
  BASE_URL = "https://nominatim.openstreetmap.org/search"

  # Retorna { lat:, lon:, display_name: } ou nil se não encontrar
  def self.geocode(address)
    return nil if address.blank?

    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(
      q:              address,
      format:         "json",
      limit:          1,
      addressdetails: 0,
      countrycodes:   "br"
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = true
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Backstage/1.0 (daniellirioreis@gmail.com)"
    request["Accept"]     = "application/json"

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    results = JSON.parse(response.body)
    return nil if results.empty?

    result = results.first
    {
      lat:          result["lat"].to_f,
      lon:          result["lon"].to_f,
      display_name: result["display_name"]
    }
  rescue StandardError
    nil
  end
end
