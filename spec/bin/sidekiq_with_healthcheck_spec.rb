require "rails_helper"
require "open3"

RSpec.describe "bin/sidekiq-with-healthcheck" do
  around do |example|
    Dir.mktmpdir do |dir|
      self.stub_dir = dir
      example.run
    end
  end

  attr_accessor :stub_dir

  def write_stub(name, body)
    path = File.join(stub_dir, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, path)
  end

  def run_script(env)
    record = File.join(stub_dir, "sidekiq_env")
    write_stub("bundle", %(printf '%s|%s' "$*" "${DATABASE_URL-unset}" > "#{record}"))
    write_stub("curl", "exit 0")
    script_env = {
      "PATH" => "#{stub_dir}:#{ENV.fetch("PATH")}",
      "SIDEKIQ_HEALTHCHECK_START_GRACE" => "0",
      "SIDEKIQ_HEALTHCHECK_INTERVAL" => "0.1"
    }.merge(env)
    output, status =
      Open3.capture2e(script_env, Rails.root.join("bin/sidekiq-with-healthcheck").to_s)
    expect(status).to be_success, output
    File.read(record)
  end

  it "starts Sidekiq with WORKER_DATABASE_URL as DATABASE_URL when it is set" do
    result =
      run_script(
        "DATABASE_URL" => "postgres://admin@db/app",
        "WORKER_DATABASE_URL" => "postgres://worker@db/app"
      )

    expect(result).to eq("exec sidekiq|postgres://worker@db/app")
  end

  it "keeps DATABASE_URL when WORKER_DATABASE_URL is empty" do
    result = run_script("DATABASE_URL" => "postgres://admin@db/app", "WORKER_DATABASE_URL" => "")

    expect(result).to eq("exec sidekiq|postgres://admin@db/app")
  end

  it "keeps DATABASE_URL when WORKER_DATABASE_URL is not set" do
    result = run_script("DATABASE_URL" => "postgres://admin@db/app", "WORKER_DATABASE_URL" => nil)

    expect(result).to eq("exec sidekiq|postgres://admin@db/app")
  end
end
