class ReviewApprover
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript

  SYSTEM_DIRECTIVE = <<~TEXT
    Your task is to check if the given data is a review of the ink specified or not.
    At then end you can either approve or reject the review.

    * Reject reviews that are not related to the ink.
    * Approve reviews that are related to the ink.
    * Reject reviews that are instagram posts.
    * For YouTube videos that are not shorts, approve the review if it is related to the ink.
    * For YouTube videos that are shorts, approve the review if it is related to the ink AND there are no reviews for the ink, yet.
  TEXT

  def initialize(ink_review_id)
    self.ink_review = InkReview.find(ink_review_id)
    transcript << { system: SYSTEM_DIRECTIVE }
    transcript << { user: macro_cluster_data }
    transcript << { user: review_data }
    transcript << { user: approved_reviews_data }
    transcript << { user: rejected_reviews_data }
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4o-mini")
    agent_log.update!(extra_data: ink_review.extra_data)
    agent_log.waiting_for_approval!
  end

  def agent_log
    @agent_log ||= ink_review.agent_logs.create!(name: self.class.name, transcript: [])
  end

  private

  attr_accessor :ink_review

  delegate :macro_cluster, to: :ink_review

  def macro_cluster_data
    data = format_cluster_data(macro_cluster)
    "The data for the ink is: #{data.to_json}"
  end

  def format_cluster_data(cluster)
    {
      name: cluster.name,
      synonyms: cluster.synonyms,
      number_of_reviews: cluster.ink_reviews.approved.size
    }
  end

  def review_data
    data = format_review_data(ink_review)

    "The review data is: #{data.to_json}"
  end

  def format_review_data(review)
    data = {
      title: review.title,
      description: review.description,
      url: review.url,
      thumbnail_url: review.image,
      host: review.host,
      author: review.author,
      user: review.user.admin? ? "System" : (review.user.name.presence || review.user.email)
    }
    if review.you_tube_channel
      data[:is_you_tube_video] = true
      data[:is_youtube_short] = review.you_tube_short?
    end
    data
  end

  def approved_reviews_data
    data = admin_reviews.approved.limit(10).map { |r| format_review_data(r) }
    data += user_reviews.approved.limit(10).map { |r| format_review_data(r) }
    "Here are some examples of approved reviews: #{data.to_json}"
  end

  def rejected_reviews_data
    data = admin_reviews.rejected.limit(10).map { |r| format_review_data(r) }
    data += user_reviews.rejected.limit(10).map { |r| format_review_data(r) }
    "Here are some examples of rejected reviews: #{data.to_json}"
  end

  def admin_reviews
    reviews.where(ink_review_submissions: { user: User.admins })
  end

  def user_reviews
    reviews.where.not(ink_review_submissions: { user: User.admins })
  end

  def reviews
    InkReview.joins(:ink_review_submissions).order(created_at: :desc)
  end

  function :approve_review, "Approve the review" do
    ink_review.update(extra_data: { action: "approve_review" })
    stop_looping!
  end

  function :reject_review, "Reject the review" do
    ink_review.update(extra_data: { action: "reject_review" })
    stop_looping!
  end
end
