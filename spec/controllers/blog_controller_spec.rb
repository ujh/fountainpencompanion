require "rails_helper"

describe BlogController do
  render_views

  describe "#feed" do
    it "renders the feed" do
      create(:blog_post, published_at: 1.hour.ago)

      get :feed, format: :rss
      expect(response).to be_successful
    end
  end
end
