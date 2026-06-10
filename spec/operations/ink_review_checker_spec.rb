require "rails_helper"

describe InkReviewChecker do
  let(:review) do
    create(
      :ink_review,
      url: "http://example.com/review",
      title: "old title",
      description: "old description",
      image: "http://example.com/old-image.jpg",
      author: "old author",
      approved_at: Time.now,
      next_check_at: 1.hour.ago,
      check_count: 0
    )
  end

  let(:fresh_data) do
    Unfurler::Result.new(
      "http://example.com/review",
      "fresh title",
      "fresh description",
      "http://example.com/fresh-image.jpg",
      "fresh author",
      nil,
      false,
      ""
    )
  end

  before { allow_any_instance_of(Unfurler).to receive(:perform).and_return(fresh_data) }

  def stub_image_ok
    stub_request(:head, fresh_data.image).to_return(status: 200)
  end

  def stub_image_404
    stub_request(:head, fresh_data.image).to_return(status: 404)
  end

  describe "successful check" do
    before { stub_image_ok }

    it "updates the review with fresh metadata" do
      described_class.new(review).perform
      review.reload
      expect(review.title).to eq("fresh title")
      expect(review.description).to eq("fresh description")
      expect(review.image).to eq("http://example.com/fresh-image.jpg")
      expect(review.author).to eq("fresh author")
    end

    it "resets check_count and schedules next check 2 months out" do
      review.update!(check_count: 2)
      described_class.new(review).perform
      review.reload
      expect(review.check_count).to eq(0)
      expect(review.next_check_at).to be_within(1.minute).of(InkReview::CHECK_INTERVAL.from_now)
    end

    it "records a success check" do
      expect { described_class.new(review).perform }.to change(InkReviewCheck, :count).by(1)
      expect(InkReviewCheck.last.result).to eq("success")
    end

    it "leaves approved_at intact" do
      original = review.approved_at
      described_class.new(review).perform
      expect(review.reload.approved_at).to be_within(1.second).of(original)
    end
  end

  describe "image unreachable" do
    before { stub_image_404 }

    it "increments check_count and schedules a 24h retry" do
      described_class.new(review).perform
      review.reload
      expect(review.check_count).to eq(1)
      expect(review.next_check_at).to be_within(1.minute).of(InkReview::RETRY_INTERVAL.from_now)
    end

    it "records an error check with a message" do
      expect { described_class.new(review).perform }.to change(InkReviewCheck, :count).by(1)
      check = InkReviewCheck.last
      expect(check.result).to eq("error")
      expect(check.error_message).to eq("Image unreachable")
    end

    it "leaves the review's metadata untouched (does not save garbage from a broken page)" do
      described_class.new(review).perform
      review.reload
      expect(review.title).to eq("old title")
      expect(review.description).to eq("old description")
      expect(review.image).to eq("http://example.com/old-image.jpg")
      expect(review.author).to eq("old author")
    end
  end

  describe "blank image returned by the unfurler" do
    let(:fresh_data) do
      Unfurler::Result.new(
        "http://example.com/review",
        "fresh title",
        "fresh description",
        "",
        "fresh author",
        nil,
        false,
        ""
      )
    end

    it "records an error check" do
      described_class.new(review).perform
      check = InkReviewCheck.last
      expect(check.result).to eq("error")
      expect(check.error_message).to eq("Image unreachable")
    end
  end

  describe "Faraday error during unfurl" do
    before do
      allow_any_instance_of(Unfurler).to receive(:perform).and_raise(
        Faraday::ConnectionFailed.new("connection refused")
      )
    end

    it "records an error check with the exception message" do
      described_class.new(review).perform
      check = InkReviewCheck.last
      expect(check.result).to eq("error")
      expect(check.error_message).to include("connection refused")
    end

    it "increments check_count and schedules a 24h retry" do
      described_class.new(review).perform
      review.reload
      expect(review.check_count).to eq(1)
      expect(review.next_check_at).to be_within(1.minute).of(InkReview::RETRY_INTERVAL.from_now)
    end
  end

  describe "Google API error during youtube unfurl" do
    before do
      allow_any_instance_of(Unfurler).to receive(:perform).and_raise(
        Google::Apis::ClientError.new("notFound: video not found")
      )
    end

    it "records an error check rather than letting the worker retry forever" do
      described_class.new(review).perform
      check = InkReviewCheck.last
      expect(check.result).to eq("error")
      expect(check.error_message).to include("notFound")
    end
  end

  describe "YouTube video not found (deleted/private)" do
    before do
      allow_any_instance_of(Unfurler).to receive(:perform).and_raise(
        Google::Apis::ClientError.new("YouTube video not found: abc123")
      )
    end

    it "records an error check" do
      described_class.new(review).perform
      check = InkReviewCheck.last
      expect(check.result).to eq("error")
      expect(check.error_message).to include("YouTube video not found")
    end
  end

  describe "URI::InvalidURIError raised by the unfurler" do
    before do
      allow_any_instance_of(Unfurler).to receive(:perform).and_raise(
        URI::InvalidURIError.new("bad uri")
      )
    end

    it "records an error check" do
      described_class.new(review).perform
      check = InkReviewCheck.last
      expect(check.result).to eq("error")
      expect(check.error_message).to include("bad uri")
    end
  end

  describe "fresh page returns invalid metadata (e.g., nil title)" do
    let(:fresh_data) do
      Unfurler::Result.new(
        "http://example.com/review",
        nil,
        "fresh description",
        "http://example.com/fresh-image.jpg",
        "fresh author",
        nil,
        false,
        ""
      )
    end

    before { stub_image_ok }

    it "records an error check with the validation message" do
      described_class.new(review).perform
      check = InkReviewCheck.last
      expect(check.result).to eq("error")
      expect(check.error_message).to include("Title")
    end

    it "leaves the review's existing metadata in the database" do
      described_class.new(review).perform
      review.reload
      expect(review.title).to eq("old title")
    end
  end

  describe "fifth consecutive failure" do
    before do
      stub_image_404
      review.update!(check_count: 4)
    end

    it "records a removed check" do
      described_class.new(review).perform
      check = InkReviewCheck.last
      expect(check.result).to eq("removed")
    end

    it "clears next_check_at so the review is never re-checked" do
      described_class.new(review).perform
      review.reload
      expect(review.next_check_at).to be_nil
      expect(review.check_count).to eq(5)
    end
  end

  describe "recovery after a previous failure" do
    before do
      stub_image_ok
      review.update!(check_count: 3, next_check_at: 1.hour.ago)
    end

    it "resets check_count to 0" do
      described_class.new(review).perform
      expect(review.reload.check_count).to eq(0)
    end

    it "schedules next check 2 months out" do
      described_class.new(review).perform
      expect(review.reload.next_check_at).to be_within(1.minute).of(
        InkReview::CHECK_INTERVAL.from_now
      )
    end
  end

  describe "image hosted on a blocked address (SSRF regression)" do
    let(:bad_image) { "http://169.254.169.254/latest/meta-data/" }
    let(:fresh_data) do
      Unfurler::Result.new("http://example.com/review", "t", "d", bad_image, "a", nil, false, "")
    end

    before do
      allow(Resolv).to receive(:getaddresses).with("169.254.169.254").and_return(
        ["169.254.169.254"]
      )
    end

    it "records a failure rather than issuing the HEAD request" do
      described_class.new(review).perform
      expect(review.reload.ink_review_checks.last.result).to eq("error")
      # No HEAD request should have been emitted at all.
      expect(WebMock).not_to have_requested(:head, bad_image)
    end
  end
end
