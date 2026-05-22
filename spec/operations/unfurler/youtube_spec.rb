require "rails_helper"

RSpec.describe Unfurler::Youtube do
  let(:video_id) { "abc123" }

  def build_video(tags:)
    snippet =
      double(
        :snippet,
        title: "Title",
        description: "Description",
        thumbnails: double(:thumbnails, maxres: double(:t, url: "thumb.jpg")),
        channel_title: "Channel",
        channel_id: "UC123",
        tags: tags
      )
    double(:video, snippet: snippet)
  end

  before { stub_request(:get, "https://www.youtube.com/shorts/#{video_id}").to_return(status: 404) }

  it "populates the :youtube sub-hash with tags from the snippet" do
    client = double(:client, list_videos: double(:r, items: [build_video(tags: %w[a b])]))
    allow_any_instance_of(described_class).to receive(:client).and_return(client)

    result = described_class.new(video_id).perform

    expect(result.youtube).to eq(tags: %w[a b], comments: nil, captions: nil)
  end

  it "returns an empty tags array when the snippet has no tags" do
    client = double(:client, list_videos: double(:r, items: [build_video(tags: nil)]))
    allow_any_instance_of(described_class).to receive(:client).and_return(client)

    result = described_class.new(video_id).perform

    expect(result.youtube[:tags]).to eq([])
  end
end
