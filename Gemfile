source 'https://rubygems.org'

ruby '2.6.5'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 6.0.3'

gem 'barnes'
gem 'bcrypt'
gem 'bootsnap'
gem 'bootstrap-sass'
gem 'color'
gem 'devise'
gem 'exception_notification'
gem 'fast_jsonapi', git: 'https://github.com/fast-jsonapi/fast_jsonapi'
gem 'font-awesome-rails'
gem 'jbuilder'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jsonapi-rails'
gem 'kaminari'
gem 'pg'
gem 'pg_search'
gem 'puma'
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
  gem 'dotenv'
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
end
