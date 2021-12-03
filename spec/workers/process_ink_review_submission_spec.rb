require 'rails_helper'

describe ProcessInkReviewSubmission do
  let(:ink_review_submission) { create(:ink_review_submission) }

  before do
    stub_request(:get, ink_review_submission.url).to_return(
      body: file_fixture("kobe-hatoba-blue-all-attributes.html")
    )
  end

  it 'creates a new ink review if none exists' do
    expect do
      described_class.new.perform(ink_review_submission.id)
    end.to change(InkReview, :count).by(1)
  end

  it 'sets the correct attributes on the ink review' do
    described_class.new.perform(ink_review_submission.id)
    review = InkReview.first
    expect(review.url).to eq('https://mountainofink.com/blog/kobe-hatoba-blue')
    expect(review.title).to eq('Ink Review #1699: Kobe 02 Hatoba Blue — Mountain of Ink')
    expect(review.description).to eq('Kobe is a brand I come back to again and again, just because I love them so much. Today let’s look at  Kobe 02 Hatoba Blue . You can find this ink for sale at most retailers including  Vanness Pens .')
    expect(review.image).to eq('http://static1.squarespace.com/static/591a04711e5b6c3701808c11/591a07702994cadba4aeb479/61a67ef965f99c77610c2c39/1638384095123/nk-hatoba-blue-w-1.jpg?format=1500w')
    expect(review.approved_at).to eq(nil)
    expect(review.rejected_at).to eq(nil)
  end

  it 'attaches the submission to the review' do
    described_class.new.perform(ink_review_submission.id)
    review = InkReview.first
    expect(review.ink_review_submissions).to eq([ink_review_submission])
  end

  it 'attaches to an exsting ink review if one exists' do
    existing_review = create(:ink_review, url: 'https://mountainofink.com/blog/kobe-hatoba-blue')
    expect do
      described_class.new.perform(ink_review_submission.id)
    end.not_to change(InkReview, :count)
    expect(existing_review.ink_review_submissions).to eq([ink_review_submission])
  end
end
