require "rails_helper"

RSpec.describe Youtube::Client do
  before { allow_any_instance_of(described_class).to receive(:authorize).and_return(nil) }

  it "identifies the app at the start of the User-Agent sent to the YouTube API" do
    stub =
      stub_request(:get, %r{\Ahttps://youtube\.googleapis\.com/youtube/v3/videos}).with(
        headers: {
          "User-Agent" => /\A#{Regexp.escape(Fountainpencompanion::USER_AGENT)} google-apis-/
        }
      ).to_return(
        status: 200,
        body: { items: [] }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

    described_class.new.list_videos("snippet", id: "abc123")

    expect(stub).to have_been_requested
  end
end
