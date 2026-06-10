ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "spec_helper"
require "rspec/rails"

Sidekiq.testing!(:fake)
Sidekiq.logger.level = Logger::WARN

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

  # SafeHttp (and ssrf_filter under the hood) resolve hostnames before
  # opening sockets, but test hosts are not real and we don't want to
  # depend on container DNS. Default every spec to a public IPv4 for
  # non-IP hostnames. Literal IPs pass through unchanged so SSRF guards
  # actually see the address the test used. Tests that exercise a
  # specific SSRF scenario can still override per-host.
  config.before(:each) do
    allow(Resolv).to receive(:getaddresses) do |host|
      begin
        IPAddr.new(host.to_s)
        [host.to_s]
      rescue IPAddr::InvalidAddressError
        ["93.184.216.34"]
      end
    end
  end

  config.before(:each, type: :request) { Rails.application.reload_routes_unless_loaded }
  config.before(:each, type: :controller) { Rails.application.reload_routes_unless_loaded }
end
