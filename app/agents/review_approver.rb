class ReviewApprover
  include Raix::ChatCompletion
  include Raix::FunctionDispatch

  def initialize(ink_review_id)
    self.ink_review = InkReview.find(ink_review_id)
  end

  private

  attr_accessor :ink_review
end
