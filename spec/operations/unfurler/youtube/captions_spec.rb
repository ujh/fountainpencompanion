require "rails_helper"

RSpec.describe Unfurler::Youtube::Captions do
  let(:video_id) { "abc123" }

  def stub_timedtext(params, status:, body: "")
    query = params.merge(v: video_id)
    stub_request(:get, "https://www.youtube.com/api/timedtext").with(query: query).to_return(
      status: status,
      body: body
    )
  end

  def sample_track
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <transcript>
        <text start="0.0" dur="2.0">Today we review</text>
        <text start="2.0" dur="2.0">Pilot Iroshizuku Tsuki-yo &amp; its sheen</text>
      </transcript>
    XML
  end

  it "returns parsed text from the first successful track" do
    stub_timedtext({ lang: "en" }, status: 200, body: sample_track)
    result = described_class.new(video_id).fetch
    expect(result).to eq("Today we review Pilot Iroshizuku Tsuki-yo & its sheen")
  end

  it "falls back to en-US when en returns empty body" do
    stub_timedtext({ lang: "en" }, status: 200, body: "")
    stub_timedtext({ lang: "en-US" }, status: 200, body: sample_track)
    expect(described_class.new(video_id).fetch).to include("Pilot Iroshizuku")
  end

  it "falls back to ASR when human tracks are absent" do
    stub_timedtext({ lang: "en" }, status: 404)
    stub_timedtext({ lang: "en-US" }, status: 404)
    stub_timedtext({ lang: "en", kind: "asr" }, status: 200, body: sample_track)
    expect(described_class.new(video_id).fetch).to include("Pilot Iroshizuku")
  end

  it "returns nil when all attempts fail or are empty" do
    stub_timedtext({ lang: "en" }, status: 404)
    stub_timedtext({ lang: "en-US" }, status: 404)
    stub_timedtext({ lang: "en", kind: "asr" }, status: 404)
    stub_timedtext({ lang: "en-US", kind: "asr" }, status: 404)
    expect(described_class.new(video_id).fetch).to be_nil
  end

  it "truncates captions exceeding MAX_CHARS" do
    long_text = "x" * (described_class::MAX_CHARS + 500)
    long_body = "<transcript><text>#{long_text}</text></transcript>"
    stub_timedtext({ lang: "en" }, status: 200, body: long_body)
    result = described_class.new(video_id).fetch
    expect(result.length).to eq(described_class::MAX_CHARS)
  end

  it "returns nil when Faraday raises" do
    allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(
      Faraday::ConnectionFailed.new("boom")
    )
    expect(described_class.new(video_id).fetch).to be_nil
  end
end
