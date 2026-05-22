class ReviewApprover
  include RubyLlmAgent

  class ApproveReview < RubyLLM::Tool
    description "Approve the review to make it customer visible"

    param :explanation_of_decision,
          desc: "Provide a brief explanation of why you are approving this review."

    attr_accessor :ink_review

    def initialize(ink_review)
      self.ink_review = ink_review
    end

    def execute(explanation_of_decision:)
      ink_review.update(
        extra_data:
          ink_review.extra_data.merge(
            action: "approve_review",
            explanation_of_decision: explanation_of_decision
          )
      )
      ink_review.agent_approve!
      halt "approved"
    end
  end

  class RejectReview < RubyLLM::Tool
    description "Reject the review to ensure it is hidden from public view"

    param :explanation_of_decision,
          desc: "Provide a brief explanation of why you are rejecting this review."

    attr_accessor :ink_review

    def initialize(ink_review)
      self.ink_review = ink_review
    end

    def execute(explanation_of_decision:)
      ink_review.update(
        extra_data:
          ink_review.extra_data.merge(
            action: "reject_review",
            explanation_of_decision: explanation_of_decision
          )
      )
      ink_review.agent_reject!
      halt "rejected"
    end
  end

  class Summarize < RubyLLM::Tool
    description "Return a summary of the web page"

    attr_accessor :ink_review, :agent_log

    def initialize(ink_review, agent_log)
      self.ink_review = ink_review
      self.agent_log = agent_log
    end

    def execute
      if ink_review.you_tube_channel_id.present?
        ink_review.ensure_youtube_metadata!
        summary = YoutubeSummarizer.new(agent_log, ink_review).perform
        "Here is a summary of the YouTube video:\n\n#{summary}"
      else
        page_data = Unfurler.new(ink_review.url).perform
        summary = WebPageSummarizer.new(agent_log, page_data.raw_html).perform
        "Here is a summary of the page:\n\n#{summary}"
      end
    end
  end

  MODEL_ID = "gpt-4.1-mini"

  SYSTEM_DIRECTIVE = <<~TEXT
    Your task is to check if the given data is a review of the ink specified or not.
    At then end you can either approve or reject the review.

    * Reject reviews that are not related to the ink.
    * Approve reviews that are related to the ink.
    * Reject reviews that are instagram posts.
    * Reject reviews that are unboxing, currently inked, or live videos or blog posts
      UNLESS the ink in question has no reviews at all.
    * For YouTube videos that are not shorts, approve the review if it is related to the ink.
    * For YouTube videos that are shorts, approve the review if it is related to the ink AND there are no reviews for the ink, yet.
    * Before rejecting a review that was not submitted by "System", double check with the `summarize` function
      that the ink does not appear in the review, after all.
    * Reviews that are not submitted by user "System" have a higher likelihood of being correct.

    For both web pages and Youtube videos you can call the `summarize` function to get a summary.
    For Youtube videos the summary draws on the video's captions (when available) and thumbnail.

    For Youtube videos the review data also includes `youtube_tags`, the top three relevance-ranked
    `top_comments`, and a `has_captions` boolean. Use these to judge the review without always calling
    `summarize` — call it for borderline cases or when `has_captions` is true and you want the
    transcript-derived content.

    A thumbnail image of the video or page is attached to this message. Use it to confirm the ink
    identity when the text is ambiguous — many ink-review thumbnails show the ink bottle and/or the
    ink name as a text overlay.
  TEXT

  def initialize(ink_review_id)
    self.ink_review = InkReview.find(ink_review_id)
  end

  def perform
    ink_review.ensure_youtube_metadata!
    ask!(user_prompt, with: ink_review.image.presence)
    agent_log.update!(extra_data: ink_review.extra_data)
    agent_log.waiting_for_approval!
  end

  def agent_log = find_or_create_agent_log(ink_review)

  private

  attr_accessor :ink_review

  delegate :macro_cluster, to: :ink_review

  def tools
    [
      ApproveReview.new(ink_review),
      RejectReview.new(ink_review),
      Summarize.new(ink_review, agent_log)
    ]
  end

  def user_prompt
    [
      "The year is #{Time.current.year}.",
      macro_cluster_data,
      review_data,
      approved_reviews_data,
      rejected_reviews_data
    ].join("\n\n")
  end

  def macro_cluster_data
    data = format_cluster_data(macro_cluster)
    "The data for the ink is: #{data.to_json}"
  end

  def format_cluster_data(cluster)
    {
      name: cluster.name,
      synonyms: cluster.synonyms,
      number_of_reviews: cluster.ink_reviews.live.size
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
      user:
        (
          if review.user.admin?
            "System"
          else
            (review.user.name.presence || review.user.email)
          end
        )
    }
    if review.you_tube_channel
      data[:is_you_tube_video] = true
      data[:is_youtube_short] = review.you_tube_short?
      data[:youtube_tags] = review.youtube_tags
      data[:top_comments] = Array(review.youtube_comments)
        .first(3)
        .map { |c| c.slice("author", "text") }
      data[:has_captions] = review.youtube_captions.present?
    end
    data
  end

  def approved_reviews_data
    data =
      [admin_reviews, user_reviews].flat_map do |relation|
          [
            relation.where("ink_reviews.extra_data->>'action' = ?", "approve_review"),
            relation.where("ink_reviews.extra_data->>'action' = ?", "reject_review")
          ]
        end
        .flat_map { |relation| relation.approved.limit(5).map { |r| format_review_data(r) } }
    "Here are some examples of approved reviews: #{data.to_json}"
  end

  def rejected_reviews_data
    data =
      [admin_reviews, user_reviews].flat_map do |relation|
          [
            relation.where("ink_reviews.extra_data->>'action' = ?", "approve_review"),
            relation.where("ink_reviews.extra_data->>'action' = ?", "reject_review")
          ]
        end
        .flat_map { |relation| relation.rejected.limit(5).map { |r| format_review_data(r) } }
    "Here are some examples of rejected reviews: #{data.to_json}"
  end

  def admin_reviews
    reviews.where(ink_review_submissions: { user: User.admins })
  end

  def user_reviews
    reviews.where.not(ink_review_submissions: { user: User.admins })
  end

  def reviews
    InkReview.joins(:ink_review_submissions).order("RANDOM()").manually_processed
  end
end
