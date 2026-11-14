require "rails_helper"

describe FetchReviews::YoutubeChannel do
  subject { described_class.new }

  let(:videos) { (0...10).map { |i| { title: "title#{i}", url: "url#{i}" } } }
  let(:client) { double(:client, fetch_videos: videos) }

  before { allow(subject).to receive(:client).and_return(client) }

  def enqueued_pages
    FetchReviews::ProcessWebPageForReview.jobs.map do |job|
      WebPageForReview.find(job["args"].first)
    end
  end

  context "for a newly added channel" do
    let(:channel) { create(:you_tube_channel, back_catalog_imported: false) }

    it "processes the five newest videos" do
      subject.perform(channel.channel_id)

      expect(enqueued_pages.map(&:url)).to eq(%w[url0 url1 url2 url3 url4])
      expect(WebPageForReview.order(:id).map { |page| [page.url, page.data["search_term"]] }).to eq(
        (0...5).map { |i| ["url#{i}", "title#{i}"] }
      )
    end
  end

  context "for a channel fetched before" do
    let(:channel) { create(:you_tube_channel, back_catalog_imported: true) }

    it "processes the five newest videos" do
      subject.perform(channel.channel_id)

      expect(enqueued_pages.map(&:url)).to eq(%w[url0 url1 url2 url3 url4])
    end

    it "skips videos that already have a page without looking further back" do
      existing = WebPageForReview.create!(url: "url1", state: "processed")

      subject.perform(channel.channel_id)

      expect(enqueued_pages.map(&:url)).to eq(%w[url0 url2 url3 url4])
      expect(existing.reload.state).to eq("processed")
      expect(WebPageForReview.where(url: %w[url5 url6 url7 url8 url9])).to be_empty
    end
  end
end
