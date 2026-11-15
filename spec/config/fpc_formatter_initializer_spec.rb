require "rails_helper"
require "open3"

RSpec.describe "config/initializers/fpc_formatter.rb" do
  it "loads the markdown renderer at boot, before any timed render" do
    env = {
      "RAILS_ENV" => "production",
      "SECRET_KEY_BASE_DUMMY" => "1",
      "REDIS_CACHE_URL" => "redis://localhost:6379/0"
    }
    script = <<~RUBY
      print $LOADED_FEATURES.grep(%r{kramdown/(parser/kramdown|converter/math_engine/mathjax)}).size
    RUBY
    output, status = Open3.capture2e(env, "bin/rails", "runner", script, chdir: Rails.root)

    expect(status).to be_success, output
    expect(output.lines.last.to_i).to be >= 25
  end
end
