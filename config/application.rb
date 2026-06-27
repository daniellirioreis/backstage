require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Backstage
  class Application < Rails::Application
    config.load_defaults 7.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "America/Sao_Paulo"
    config.i18n.default_locale = :"pt-BR"
    config.i18n.available_locales = [:"pt-BR", :en]
    config.generators.system_tests = nil
  end
end
