require "rails_helper"

describe Youtube do
  subject { described_class.new(channel_id: "channel_id", client: client) }

  describe "#channel_name" do
    let(:client) do
      double(
        :client,
        list_channels:
          double(
            :channels,
            items: [double(:item, snippet: double(:snippet, title: "channel_name"))]
          )
      )
    end

    it "returns the channel name" do
      expect(subject.channel_name).to eq("channel_name")
    end
  end

  describe "#fetch_videos" do
    let(:client) do
      double(
        :client,
        list_channels:
          double(
            items: [
              double(content_details: double(related_playlists: double(uploads: "uploads_id")))
            ]
          ),
        list_playlist_items: list_playlist_items
      )
    end
    let(:list_playlist_items) do
      list_double = double(:list_playlist_items)
      video1 =
        double(:video, snippet: double(resource_id: double(video_id: "video1"), title: "title1"))
      video2 =
        double(:video, snippet: double(resource_id: double(video_id: "video2"), title: "title2"))
      allow(list_double).to receive(:items).and_return([video1], [video2])
      allow(list_double).to receive(:next_page_token).and_return("token", nil)
      list_double
    end

    it "returns the video info" do
      expect(subject.fetch_videos.to_a).to eq(
        [
          { url: "https://youtube.com/watch?v=video1", title: "title1" },
          { url: "https://youtube.com/watch?v=video2", title: "title2" }
        ]
      )
    end
  end
end
