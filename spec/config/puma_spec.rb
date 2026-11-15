require "rails_helper"
require "open3"

RSpec.describe "config/puma.rb" do
  def database_url_after_loading(env)
    script = <<~RUBY
      require "puma"
      require "puma/configuration"
      Puma::Configuration.new(config_files: ["config/puma.rb"]).load
      print ENV.fetch("DATABASE_URL", "unset")
    RUBY
    output, status = Open3.capture2e(env, "ruby", "-e", script, chdir: Rails.root)
    expect(status).to be_success, output
    output
  end

  it "uses WEB_DATABASE_URL as DATABASE_URL when it is set" do
    url =
      database_url_after_loading(
        "DATABASE_URL" => "postgres://admin@db/app",
        "WEB_DATABASE_URL" => "postgres://web@db/app"
      )

    expect(url).to eq("postgres://web@db/app")
  end

  it "keeps DATABASE_URL when WEB_DATABASE_URL is empty" do
    url =
      database_url_after_loading(
        "DATABASE_URL" => "postgres://admin@db/app",
        "WEB_DATABASE_URL" => ""
      )

    expect(url).to eq("postgres://admin@db/app")
  end

  it "keeps DATABASE_URL when WEB_DATABASE_URL is not set" do
    url =
      database_url_after_loading(
        "DATABASE_URL" => "postgres://admin@db/app",
        "WEB_DATABASE_URL" => nil
      )

    expect(url).to eq("postgres://admin@db/app")
  end
end
