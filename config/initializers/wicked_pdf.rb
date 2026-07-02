WickedPdf.configure do |config|
  config.exe_path = begin
    WickedPdfHelper.find_wkhtmltopdf_binary_path
  rescue StandardError
    "/usr/bin/wkhtmltopdf"
  end
end
