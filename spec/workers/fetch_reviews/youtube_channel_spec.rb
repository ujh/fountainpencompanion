require "rails_helper"

describe FetchReviews::YoutubeChannel do
  subject { described_class.new }

  let(:client) do
    double(:client, fetch_videos: (0...10).map { |i| { title: "title#{i}", url: "url#{i}" } })
  end

  before { allow(subject).to receive(:client).and_return(client) }

  context "back catalog imported" do
    let(:channel) { create(:you_tube_channel, back_catalog_imported: true) }

    it "submits the first five reviews" do
      expect do subject.perform(channel.channel_id) end.to change {
        FetchReviews::ProcessWebPageForReview.jobs.count
      }.by(5)
    end

    it "submits the correct data" do
      expect do subject.perform(channel.channel_id) end.to change(WebPageForReview, :count).by(5)
      job = FetchReviews::ProcessWebPageForReview.jobs.first
      page = WebPageForReview.find(job["args"].first)
      expect(page.url).to eq("url0")
    end
  end

  context "back catalog not imported" do
    let(:channel) { create(:you_tube_channel, back_catalog_imported: false) }

    it "still only submits the latest five reviews" do
      expect do subject.perform(channel.channel_id) end.to change {
        FetchReviews::ProcessWebPageForReview.jobs.count
      }.by(5)
    end

    it "sets back_catalog_imported to true" do
      expect do subject.perform(channel.channel_id) end.to change {
        channel.reload.back_catalog_imported
      }.to(true)
    end
  end
end
