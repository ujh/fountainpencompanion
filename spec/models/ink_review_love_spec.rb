require "rails_helper"

describe InkReviewLove do
  let(:ink_review) { create(:ink_review) }
  let(:user) { create(:user) }

  it "increments the review's loves count" do
    expect { create(:ink_review_love, ink_review: ink_review, user: user) }.to change {
      ink_review.reload.loves_count
    }.from(0).to(1)
  end

  it "decrements the review's loves count when destroyed" do
    love = create(:ink_review_love, ink_review: ink_review, user: user)

    expect { love.destroy }.to change { ink_review.reload.loves_count }.from(1).to(0)
  end

  it "does not decrement the count twice when a stale copy is destroyed" do
    love = create(:ink_review_love, ink_review: ink_review, user: user)
    stale_copy = InkReviewLove.find(love.id)
    love.destroy

    expect { stale_copy.destroy }.not_to change { ink_review.reload.loves_count }
  end

  it "allows only one love per user and review" do
    create(:ink_review_love, ink_review: ink_review, user: user)

    expect { create(:ink_review_love, ink_review: ink_review, user: user) }.to raise_error(
      ActiveRecord::RecordNotUnique
    )
  end

  it "is removed together with the review" do
    create(:ink_review_love, ink_review: ink_review, user: user)

    expect { ink_review.destroy }.to change(InkReviewLove, :count).by(-1)
  end

  it "is removed with the user and stops counting" do
    create(:ink_review_love, ink_review: ink_review, user: user)

    expect { user.destroy }.to change { ink_review.reload.loves_count }.from(1).to(0)
  end
end
