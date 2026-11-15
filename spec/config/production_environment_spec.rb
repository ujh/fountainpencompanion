require "rails_helper"
require "open3"

RSpec.describe "config/environments/production.rb" do
  def production_config_value(expression)
    env = {
      "RAILS_ENV" => "production",
      "SECRET_KEY_BASE_DUMMY" => "1",
      "REDIS_CACHE_URL" => "redis://localhost:6379/0"
    }
    output, status =
      Open3.capture2e(env, "bin/rails", "runner", "print(#{expression})", chdir: Rails.root)
    expect(status).to be_success, output
    output.lines.last
  end

  it "serves only precompiled assets" do
    expect(production_config_value("Rails.application.config.assets.compile")).to eq("false")
  end
end
