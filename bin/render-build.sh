#!/usr/bin/env bash
# render-build-reset.sh
# Usado pelo reset-render-db.sh para zerar e recriar o banco no Render.
# NÃO use diretamente como build command — apenas via reset-render-db.sh.
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:schema:load
bundle exec rails runner db/seeds/00_plans.rb
bundle exec rails runner db/seeds/01_roles.rb
bundle exec rails runner db/seeds/02_admin_user.rb
