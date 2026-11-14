require "rails_helper"

RSpec.describe GoogleSearch do
  around do |example|
    previous = ENV["SERPER_API_KEY"]
    ENV["SERPER_API_KEY"] = "serper-key"
    example.run
    ENV["SERPER_API_KEY"] = previous
  end

  it "identifies the app to Serper" do
    stub =
      stub_request(:post, "https://google.serper.dev/search").with(
        headers: {
          "User-Agent" => Fountainpencompanion::USER_AGENT,
          "X-API-KEY" => "serper-key"
        }
      ).to_return(
        status: 200,
        body: { organic: [] }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

    described_class.new("Pilot Iroshizuku").perform

    expect(stub).to have_been_requested
  end
end
