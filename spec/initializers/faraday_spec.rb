require "rails_helper"

RSpec.describe "Faraday User-Agent" do
  it "identifies the app on a connection that sets no User-Agent" do
    stub_request(:get, "https://example.test/").with(
      headers: {
        "User-Agent" => Fountainpencompanion::USER_AGENT
      }
    ).to_return(status: 200, body: "ok")

    expect(Faraday.new("https://example.test/").get("/").body).to eq("ok")
  end

  it "identifies the app on the default connection" do
    stub_request(:get, "https://example.test/").with(
      headers: {
        "User-Agent" => Fountainpencompanion::USER_AGENT
      }
    ).to_return(status: 200, body: "ok")

    expect(Faraday.get("https://example.test/").body).to eq("ok")
  end

  it "keeps the User-Agent a connection sets itself" do
    stub_request(:get, "https://example.test/").with(
      headers: {
        "User-Agent" => "SomeGem/1.0"
      }
    ).to_return(status: 200, body: "ok")

    connection = Faraday.new("https://example.test/", headers: { "User-Agent" => "SomeGem/1.0" })

    expect(connection.get("/").body).to eq("ok")
  end
end
