source 'https://rubygems.org'

ruby '2.7.4'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 7.0.2'

gem 'barnes'
gem 'bcrypt'
gem 'bootsnap'
gem 'bootstrap-sass'
gem 'color'
gem 'devise'
gem 'exception_notification'
gem 'faraday'
gem 'faraday_middleware'
gem 'font-awesome-rails'
gem 'google-apis-youtube_v3'
gem 'gutentag'
gem 'jbuilder'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jsonapi-rails'
gem 'jsonapi-serializer'
gem 'kaminari'
gem 'newrelic_rpm'
gem 'nokogiri'
gem 'pg'
gem 'pg_search'
gem 'puma'
gem 'puma_worker_killer'
gem 'rails-assets-select2', '4.0.8', source: 'https://rails-assets.org' # Select2 4.0.6 breaks the currently inked page
gem 'redis'
gem 'ruby-progressbar'
gem 'sass-rails'
gem 'scenic'
gem 'sidekiq'
gem 'sidekiq-scheduler'
gem 'simple_form'
gem 'slim'
gem 'slodown'
gem 'strong_migrations'
gem 'uglifier'
gem 'webpacker'

group :development, :test do
  gem 'byebug', platform: :mri
  gem 'dotenv-rails'
  gem 'letter_opener'
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end

group :development do
  gem 'derailed'
  gem 'listen'
  gem 'web-console'
end

group :test do
  gem 'rails-controller-testing'
  gem 'simplecov', require: false
  gem 'simplecov-lcov', require: false
  gem 'webmock'
end
