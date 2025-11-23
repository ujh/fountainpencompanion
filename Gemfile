source "https://rubygems.org"

ruby "3.4.4"

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem "rails", "~> 8.1.1"

gem "bcrypt"
gem "bootsnap"
gem "breadcrumbs_on_rails"
gem "color"
gem "csv"
gem "devise"
gem "devise-passwordless"
gem "differ"
gem "faraday"
gem "faraday-follow_redirects"
gem "font-awesome-rails"
gem "google-apis-youtube_v3"
gem "gutentag", "~> 3.0"
gem "honeybadger"
gem "jbuilder"
gem "jquery-rails"
gem "jquery-ui-rails"
gem "jsbundling-rails"
gem "jsonapi-rails"
gem "jsonapi-serializer"
gem "kaminari"
gem "neighbor"
gem "newrelic_rpm"
gem "nokogiri"
gem "paper_trail"
gem "pg"
gem "pghero"
gem "pg_query", ">= 2"
gem "pg_search"
gem "puma"
gem "puma_worker_killer"
gem "rack-attack"
gem "rack-timeout"
gem "rails-assets-select2", "4.0.13", source: "https://rails-assets.org" # Select2 4.0.6 breaks the currently inked page
gem "raix", "1.0.3"
gem "redis"
gem "rss"
gem "ruby-progressbar"
gem "sanitize", "~> 7.0.0"
gem "sass-rails"
gem "scenic"
gem "sidekiq"
gem "sidekiq-scheduler"
gem "sidekiq-throttled"
gem "simple_form"
gem "slim"
gem "slodown"
gem "sprockets-rails"
gem "strong_migrations"
gem "user_agent_parser"

group :development, :test do
  gem "byebug", platform: :mri
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "letter_opener"
  gem "letter_opener_web"
  gem "rspec-rails"
end

group :development do
  gem "derailed"
  gem "listen"
  gem "prettier_print", "~> 1.2"
  gem "ruby-lsp"
  gem "syntax_tree", "~> 6.3"
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
