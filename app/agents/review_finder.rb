class ReviewFinder
  include RubyLlmAgent

  class SubmitReview < RubyLLM::Tool
    description "Submit a review for the ink clusters"

    param :ink_cluster_id,
          type: "integer",
          desc:
            "The ID of the ink cluster to submit the review for. Found via the similarity search"
    param :explanation, desc: "An explanation of why this ink cluster was chosen for the review"

    attr_accessor :page

    def initialize(page)
      self.page = page
    end

    def execute(ink_cluster_id:, explanation:)
      cluster = MacroCluster.find_by(id: ink_cluster_id)
      if cluster.nil?
        "I couldn't find the ink cluster with ID #{ink_cluster_id}. Please try again."
      else
        FetchReviews::SubmitReview.perform_async(page.url, cluster.id, explanation)
        "I have submitted the review for the ink cluster with ID #{ink_cluster_id} (#{cluster.name})."
      end
    end
  end

  class Done < RubyLLM::Tool
    description "Call this if you are done submitting all reviews"

    param :summary, desc: "A summary of the actions you have taken"

    attr_accessor :agent_log

    def initialize(agent_log)
      self.agent_log = agent_log
    end

    def execute(summary:)
      agent_log.update!(extra_data: (agent_log.extra_data || {}).merge(summary: summary))
      halt "done"
    end
  end

  class Summarize < RubyLLM::Tool
    description "Return a summary of the web page"

    attr_accessor :page_data, :agent_log

    def initialize(page_data, agent_log)
      self.page_data = page_data
      self.agent_log = agent_log
    end

    def execute
      if page_data.you_tube_channel_id.present?
        summary = YoutubeSummarizer.new(agent_log, page_data).perform
        "Here is a summary of the YouTube video:\n\n#{summary}"
      else
        summary = WebPageSummarizer.new(agent_log, page_data.raw_html).perform
        "Here is a summary of the page:\n\n#{summary}"
      end
    end
  end

  MODEL_ID = "gpt-4.1"

  SYSTEM_DIRECTIVE = <<~TEXT
    You will be given details about a web page or Youtube video below. The page
    or video are not random, but most likely reviews of fountain pens or inks.

    Your task is a follows:

    1. Determine if the page or video contains reviews of fountain pen inks.
    2. If it does, determine if the inks are the main focus of the page or video.
       Be strict about this: the page or video should be primarily about inks,
       not just a passing mention or a small section about inks. Err on the
       side of caution and only consider pages or videos that are clearly
       focused on inks. "Currently inked", "unboxing", or "live" style videos or pages
       should not be considered, as they are not primarily about inks.
    3. If they are, find the inks in the internal database using the similarity
       search and submit a review for them.
    4. If the page or video does not contain reviews of inks, do not submit any
       reviews.

    You will be given a prompt with the page data, which contains information
    about the page or video, such as its title, description, and content. For
    Youtube videos the page data also includes a `youtube` sub-hash with tags,
    top comments, and captions (when available). Use these to determine if the
    page or video contains reviews of inks.

    For web pages and Youtube videos alike you can call the `summarize` function
    to get a more detailed summary. For Youtube videos the summary draws on the
    captions and thumbnail.

    A thumbnail image of the page or video is attached to this message. Use it
    to confirm the ink identity when the text is ambiguous — many ink-review
    thumbnails show the ink bottle and/or the ink name as a text overlay.
  TEXT

  def initialize(page)
    self.page = page
  end

  def perform
    ask(user_prompt, with: resolved_image_url)
    agent_log.waiting_for_approval!
  end

  def agent_log = find_or_create_agent_log(page)

  private

  attr_accessor :page

  def tools
    [
      SubmitReview.new(page),
      Done.new(agent_log),
      Summarize.new(page_data, agent_log),
      Tools::InkSimilaritySearchTool.new,
      Tools::InkFullTextSearchTool.new
    ]
  end

  def user_prompt
    "The year is #{Time.current.year}.\n\n#{page_prompt}"
  end

  def page_prompt
    "The page data is: #{page_data.to_h.except(:raw_html).to_json}"
  end

  def page_data
    @page_data ||= Unfurler.new(page.url, with_full_metadata: true).perform
  end

  def resolved_image_url
    ResolveImageUrl.new(page_data.image).perform
  end
end
