source "https://rubygems.org"

ruby "3.2.2"

gem "rails", "~> 7.1.6"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

# Auth & Authorization
gem "devise"
gem "pundit"

# PDF
gem "wicked_pdf"
gem "wkhtmltopdf-binary"

# QR Code
gem "rqrcode"

# Bootstrap
gem "bootstrap", "~> 5.3"
gem "sassc-rails"

# Pagination
gem "will_paginate", "~> 4.0"

group :development, :test do
  gem "debug", platforms: %i[mri windows]
end

group :development do
  gem "web-console"
  gem "letter_opener_web"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
