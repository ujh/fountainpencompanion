source 'https://rubygems.org'

ruby '2.4.1'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 5.2.0.rc1'

gem 'bcrypt'
gem 'bootsnap'
gem 'bootstrap-sass'
gem 'coffee-rails'
gem 'color'
gem 'devise'
gem 'exception_notification'
gem 'font-awesome-rails'
gem 'jbuilder'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jsonapi-rails'
gem 'newrelic_rpm'
gem 'pg'
gem 'puma'
gem 'rails-assets-select2', source: 'https://rails-assets.org'
gem 'sass-rails'
gem 'scenic'
gem 'simple_form'
gem 'slim'
gem 'slodown'
gem 'uglifier'
gem 'webpacker'

group :development, :test do
  gem 'byebug', platform: :mri
  gem 'letter_opener'
  gem 'rspec-rails'
end

group :development do
  gem 'listen'
  gem 'spring-watcher-listen'
  gem 'spring'
  gem 'web-console'
end

group :test do
  gem 'simplecov', require: false
end
