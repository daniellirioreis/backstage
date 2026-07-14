#!/usr/bin/env bash
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:migrate
bundle exec rails runner db/seeds/00_plans.rb
bundle exec rails runner db/seeds/01_roles.rb
bundle exec rails runner db/seeds/02_admin_user.rb
