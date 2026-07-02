WickedPdf.configure do |config|
  config.exe_path = begin
    Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')
  rescue Gem::GemNotFoundException
    '/usr/bin/wkhtmltopdf'
  end
end
