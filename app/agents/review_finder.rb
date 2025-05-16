class ReviewFinder
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript
  include InkSimilaritySearch

  SYSTEM_DIRECTIVE = <<~TEXT
    You will be given details about a web page or Youtube video below. The page
    or video are not random, but most likely reviews of fountain pens or inks.

    Your task is to find all inks reviewed in the page or video in the internal
    database and submit it as a review for these ink clusters.

    Keep in mind:
    * The page or video may contain reviews of multiple inks.
    * The page or video may be about something completely different. Submitting
      no reviews is also an option.
    * Only submit a review for inks that are a focus of the page or video. Inks
      that only get mentioned in passing should not be submitted.
    * You can search the internal database using the similarity search to find
      the correct inks to submit the review for.
    * You can search multiple times if you need to.
    * For web pages call the `summarize` function to get a more detailed summary
      of the page, which might contain more information than is available in the
      page data.
    * Vlog style videos are usually not about a specific ink, but rather about
      other topics. In these cases, you should not submit a review.
    * "Currently inked" videos or blog posts should also not be considered.
  TEXT

  def initialize(page)
    self.page = page
    if agent_log.transcript.present?
      transcript.set!(agent_log.transcript)
    else
      transcript << { system: SYSTEM_DIRECTIVE }
      transcript << { user: page_prompt }
    end
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4.1-mini")
    agent_log.waiting_for_approval!
  end

  def agent_log
    @agent_log ||= page.agent_logs.processing.where(name: self.class.name).first
    @agent_log ||= page.agent_logs.create!(name: self.class.name, transcript: [])
  end

  private

  attr_accessor :page

  function :submit_review,
           "Submit a review for the ink clusters",
           ink_cluster_id: {
             type: "integer",
             description:
               "The ID of the ink cluster to submit the review for. Found via the similarity search"
           } do |arguments|
    cluster = MacroCluster.find_by(id: arguments["ink_cluster_id"])
    if cluster.nil?
      "I couldn't find the ink cluster with ID #{arguments["ink_cluster_id"]}. Please try again."
    else
      FetchReviews::SubmitReview.perform_async(page.url, cluster.id)
      "I have submitted the review for the ink cluster with ID #{arguments["ink_cluster_id"]} (#{cluster.name})."
    end
  end

  function :done,
           "Call this if you are done submitting all reviews",
           summary: {
             type: "string",
             description: "A summary of the actions you have taken"
           } do |arguments|
    agent_log.update!(extra_data: { summary: arguments["summary"] })
    stop_looping!
  end

  function :summarize, "Return a summary of the web page" do
    if page_data.you_tube_channel_id.present?
      "This is a Youtube video. I can't summarize it."
    else
      summary = WebPageSummarizer.new(agent_log, page_data.raw_html).perform
      "Here is a summary of the page:\n\n#{summary}"
    end
  end

  def page_prompt
    "The page data is: #{page_data.to_h.except(:raw_html).to_json}"
  end

  def page_data
    @page_data ||= Unfurler.new(page.url).perform
  end
end
