require "rails_helper"

describe IgnoreReviewSource do
  def review_for(url, **attributes)
    create(:ink_review, url: url, **attributes)
  end

  describe "#perform" do
    context "with a YouTube channel" do
      let(:you_tube_channel) { create(:you_tube_channel, ignored: false) }
      let(:ink_review) do
        review_for("https://www.youtube.com/watch?v=abc", you_tube_channel: you_tube_channel)
      end

      it "ignores the channel" do
        expect(described_class.new(ink_review).perform).to be true
        expect(you_tube_channel.reload).to be_ignored
      end

      it "does not create a feed for the host" do
        expect { described_class.new(ink_review).perform }.not_to change(ReviewFeed, :count)
      end
    end

    context "with a page found by a feed" do
      let(:feed) { create(:review_feed, host: "old-blog.example.com") }
      let(:ink_review) { review_for("https://new-blog.example.com/a-review") }

      it "ignores the feed that found a submitted URL, even on another host" do
        submission_url = "https://old-blog.example.com/a-review"
        create(
          :ink_review_submission,
          ink_review: ink_review,
          macro_cluster: ink_review.macro_cluster,
          url: submission_url
        )
        create(:web_page_for_review, url: submission_url, review_feed: feed)

        expect(described_class.new(ink_review).perform).to be true
        expect(feed.reload.state).to eq("ignored")
        expect(ReviewFeed.where(host: "new-blog.example.com")).not_to exist
      end

      it "ignores the feed that found the review's own URL" do
        create(:web_page_for_review, url: ink_review.url, review_feed: feed)

        expect(described_class.new(ink_review).perform).to be true
        expect(feed.reload.state).to eq("ignored")
      end

      it "falls back to the host when the page has no feed" do
        create(:web_page_for_review, url: ink_review.url, review_feed: nil)

        expect(described_class.new(ink_review).perform).to be true
        expect(ReviewFeed.find_by(host: "new-blog.example.com").state).to eq("ignored")
        expect(feed.reload.state).to eq("active")
      end

      it "keeps an already ignored feed ignored" do
        feed.update!(state: "ignored")
        create(:web_page_for_review, url: ink_review.url, review_feed: feed)

        expect(described_class.new(ink_review).perform).to be true
        expect(feed.reload.state).to eq("ignored")
      end

      it "keeps the feed URL so the feed can be re-enabled" do
        create(:web_page_for_review, url: ink_review.url, review_feed: feed)

        expect { described_class.new(ink_review).perform }.not_to change { feed.reload.feed_url }
      end
    end

    context "with only a host" do
      it "creates an ignored, non-curated feed row for the normalised host" do
        ink_review = review_for("https://WWW.Blog.Example.com/a-review")

        expect(described_class.new(ink_review).perform).to be true
        feed = ReviewFeed.sole
        expect(feed).to have_attributes(
          host: "blog.example.com",
          state: "ignored",
          feed_url: nil,
          curated: false
        )
      end

      %w[active no_feed failing duplicate].each do |state|
        it "ignores an existing #{state} row for the host" do
          feed =
            if state == "no_feed"
              create(:review_feed, :no_feed, host: "blog.example.com")
            elsif state == "duplicate"
              create(:review_feed, host: "blog.example.com", state: state, feed_url: nil)
            else
              create(:review_feed, host: "blog.example.com", state: state)
            end
          ink_review = review_for("https://www.blog.example.com/a-review")

          expect(described_class.new(ink_review).perform).to be true
          expect(feed.reload.state).to eq("ignored")
          expect(ReviewFeed.count).to eq(1)
        end
      end

      it "ignores a row created for the host after the lookup" do
        ink_review = review_for("https://blog.example.com/a-review")
        allow(ReviewFeed).to receive(:find_by).and_wrap_original do |original, *args|
          result = original.call(*args)
          create(:review_feed, host: "blog.example.com", state: "active")
          result
        end

        expect(described_class.new(ink_review).perform).to be true
        expect(ReviewFeed.sole.state).to eq("ignored")
      end
    end

    context "without a source to ignore" do
      it "returns false for a denylisted host" do
        ink_review = review_for("https://www.youtube.com/watch?v=abc")

        expect(described_class.new(ink_review).perform).to be false
        expect(ReviewFeed.count).to eq(0)
      end

      it "returns false for a subdomain of a denylisted host" do
        ink_review = review_for("https://m.youtube.com/watch?v=abc")

        expect(described_class.new(ink_review).perform).to be false
        expect(ReviewFeed.count).to eq(0)
      end

      it "returns false for a blank host" do
        ink_review = review_for("https://blog.example.com/a-review")
        ink_review.update_columns(host: nil)

        expect(described_class.new(ink_review).perform).to be false
        expect(ReviewFeed.count).to eq(0)
      end

      it "returns false for a host that does not normalise" do
        ink_review = review_for("https://blog.example.com/a-review")
        ink_review.update_columns(host: "not a host")

        expect(described_class.new(ink_review).perform).to be false
        expect(ReviewFeed.count).to eq(0)
      end
    end
  end

  describe "#source" do
    it "is the channel of a YouTube review" do
      you_tube_channel = create(:you_tube_channel)
      ink_review = review_for("https://www.youtube.com/watch?v=abc", you_tube_channel:)

      expect(described_class.new(ink_review).source).to eq(you_tube_channel)
    end

    it "is an unsaved feed for a host without a row" do
      source = described_class.new(review_for("https://blog.example.com/a-review")).source

      expect(source).to be_a(ReviewFeed).and(be_new_record)
      expect(source.host).to eq("blog.example.com")
    end

    it "is nil for a denylisted host" do
      expect(described_class.new(review_for("https://youtu.be/abc")).source).to be_nil
    end

    it "writes nothing" do
      ink_review = review_for("https://blog.example.com/a-review")

      expect { described_class.new(ink_review).source }.not_to change(ReviewFeed, :count)
    end
  end

  describe "#curated_feed" do
    let(:ink_review) { review_for("https://mountainofink.com/a-review") }

    %w[active failing].each do |state|
      it "is the feed when it is curated and #{state}" do
        feed = create(:review_feed, :curated, host: "mountainofink.com", state: state)

        expect(described_class.new(ink_review).curated_feed).to eq(feed)
      end
    end

    it "is nil for a curated feed that is already ignored" do
      create(:review_feed, :curated, host: "mountainofink.com", state: "ignored")

      expect(described_class.new(ink_review).curated_feed).to be_nil
    end

    it "is nil for a discovered feed" do
      create(:review_feed, host: "mountainofink.com")

      expect(described_class.new(ink_review).curated_feed).to be_nil
    end

    it "is nil for a host without a feed" do
      expect(described_class.new(ink_review).curated_feed).to be_nil
    end

    it "is nil for a YouTube channel" do
      ink_review.update!(you_tube_channel: create(:you_tube_channel))

      expect(described_class.new(ink_review).curated_feed).to be_nil
    end
  end
end
