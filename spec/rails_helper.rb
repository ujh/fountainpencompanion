ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)
# Prevent database truncation if the environment is production
if Rails.env.production?
  abort("The Rails environment is running in production mode!")
end
require "spec_helper"
require "rspec/rails"
require "sidekiq/testing"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.fixture_paths = ["#{Rails.root}/spec/fixtures"]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include ApiHelpers, type: :request

  config.before(:each) { Sidekiq::Worker.clear_all }
  config.before(:each) { Rails.cache.clear }

  config.before(:each, type: :request) do
    Rails.application.reload_routes_unless_loaded
  end
  config.before(:each, type: :controller) do
    Rails.application.reload_routes_unless_loaded
  end
end
