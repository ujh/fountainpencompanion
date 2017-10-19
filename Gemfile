source 'https://rubygems.org'

ruby '2.4.1'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 5.1.1'

gem 'airbrake'
gem 'bcrypt'
gem 'bootstrap-sass'
gem 'coffee-rails'
gem 'devise'
gem 'font-awesome-rails'
gem 'jbuilder'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'pg'
gem 'puma'
gem 'sass-rails'
gem 'scenic'
gem 'simple_form'
gem 'slim'
gem 'slodown'
gem 'uglifier'

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
