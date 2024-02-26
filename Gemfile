source "https://rubygems.org"

ruby "3.2.2"

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem "rails", "~> 7.1.3"

gem "barnes"
gem "bcrypt"
gem "bootsnap"
gem "breadcrumbs_on_rails"
gem "color"
gem "devise"
gem "devise-passwordless"
gem "differ"
gem "faraday"
gem "faraday_middleware"
gem "font-awesome-rails"
gem "google-apis-youtube_v3"
gem "gutentag"
gem "honeybadger"
gem "jbuilder"
gem "jquery-rails"
gem "jquery-ui-rails"
gem "jsbundling-rails"
gem "jsonapi-rails"
gem "jsonapi-serializer"
gem "kaminari"
gem "newrelic_rpm"
gem "nokogiri"
gem "paper_trail"
gem "pg"
gem "pg_search"
gem "puma"
gem "puma_worker_killer"
gem "rails-assets-select2", "4.0.13", source: "https://rails-assets.org" # Select2 4.0.6 breaks the currently inked page
gem "rack-attack"
gem "rack-timeout"
gem "redis"
gem "rss"
gem "ruby-progressbar"
gem "sanitize", "~> 6.1.0"
gem "sass-rails"
gem "scenic"
gem "sidekiq"
gem "sidekiq-scheduler"
gem "simple_form"
gem "slim"
gem "slodown"
gem "sprockets-rails"
gem "strong_migrations"
gem "uglifier"

group :development, :test do
  gem "byebug", platform: :mri
  gem "dotenv-rails"
  gem "letter_opener"
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :development do
  gem "derailed"
  gem "listen"
  gem "prettier_print", "~> 1.2"
  gem "syntax_tree", "~> 6.2"
  gem "syntax_tree-haml", "~> 4.0"
  gem "syntax_tree-rbs", "~> 1.0.0"
  gem "web-console"
end

group :test do
  gem "rails-controller-testing"
  gem "simplecov", require: false
  gem "simplecov-lcov", require: false
  gem "webmock"
end
