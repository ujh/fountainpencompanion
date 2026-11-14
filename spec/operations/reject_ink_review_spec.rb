require "rails_helper"

describe RejectInkReview do
  let(:ink_review) do
    create(:ink_review, url: "https://blog.example.com/a-review", approved_at: Time.current)
  end

  it "rejects the review" do
    expect(described_class.new(ink_review).perform).to be true
    expect(ink_review.reload).to be_rejected
    expect(ink_review).not_to be_approved
  end

  it "leaves the source alone by default" do
    rejection = described_class.new(ink_review)
    rejection.perform

    expect(ReviewFeed.count).to eq(0)
    expect(rejection).not_to be_source_ignored
    expect(rejection).not_to be_nothing_to_ignore
  end

  it "ignores the source when asked" do
    rejection = described_class.new(ink_review, ignore_source: true)

    expect(rejection.perform).to be true
    expect(ink_review.reload).to be_rejected
    expect(ReviewFeed.find_by(host: "blog.example.com").state).to eq("ignored")
    expect(rejection).to be_source_ignored
    expect(rejection).not_to be_nothing_to_ignore
  end

  it "still rejects when there is no source to ignore" do
    ink_review.update!(url: "https://www.youtube.com/watch?v=abc")
    rejection = described_class.new(ink_review, ignore_source: true)

    expect(rejection.perform).to be true
    expect(ink_review.reload).to be_rejected
    expect(rejection).not_to be_source_ignored
    expect(rejection).to be_nothing_to_ignore
  end

  it "does not reject when ignoring the source fails" do
    ignore = instance_double(IgnoreReviewSource)
    allow(ignore).to receive(:perform).and_raise(ActiveRecord::RecordInvalid)
    allow(IgnoreReviewSource).to receive(:new).with(ink_review).and_return(ignore)

    expect { described_class.new(ink_review, ignore_source: true).perform }.to raise_error(
      ActiveRecord::RecordInvalid
    )
    expect(ink_review.reload).not_to be_rejected
  end
end
