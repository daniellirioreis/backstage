#!/usr/bin/env bash
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean

if [ "$RESET_DB" = "true" ]; then
  echo "⚠️  RESET_DB=true detectado — zerando banco de dados..."
  bundle exec rails db:schema:load DISABLE_DATABASE_ENVIRONMENT_CHECK=1
  echo "✅ Banco zerado com sucesso."
else
  bundle exec rails db:migrate
fi

bundle exec rails runner db/seeds/00_plans.rb
bundle exec rails runner db/seeds/01_roles.rb
bundle exec rails runner db/seeds/02_admin_user.rb
bundle exec rails runner db/seeds/09_catalog_functions.rb
