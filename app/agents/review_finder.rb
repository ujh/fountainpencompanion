class ReviewFinder
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript
  include InkSimilaritySearch

  SYSTEM_DIRECTIVE = <<~TEXT
    You will be given details about a web page or Youtube video below. The page
    or video are not random, but most likely reviews of fountain pens or inks.

    Your task is a follows:

    1. Determine if the page or video contains reviews of fountain pen inks.
    2. If it does, determine if the inks are the main focus of the page or video.
       Be strict about this: the page or video should be primarily about inks,
       not just a passing mention or a small section about inks. Err on the
       side of caution and only consider pages or videos that are clearly
       focused on inks. "Currently inked" or "unboxing" style videos or pages
       should not be considered, as they are not primarily about inks.
    3. If they are, find the inks in the internal database using the similarity
       search and submit a review for them.
    4. If the page or video does not contain reviews of inks, do not submit any
       reviews.

    You will be given a prompt with the page data, which contains information
    about the page or video, such as its title, description, and content. You
    can use this information to determine if the page or video contains reviews
    of inks. For web pages call the `summarize` function to get a more detailed
    summary of the page, which might contain more information than is available
    in the page data.
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
    chat_completion(openai: "gpt-4.1")
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
           },
           explanation: {
             type: "string",
             description: "An explanation of why this ink cluster was chosen for the review"
           } do |arguments|
    cluster = MacroCluster.find_by(id: arguments["ink_cluster_id"])
    if cluster.nil?
      "I couldn't find the ink cluster with ID #{arguments["ink_cluster_id"]}. Please try again."
    else
      FetchReviews::SubmitReview.perform_async(page.url, cluster.id, arguments["explanation"])
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
    stop_tool_calls_and_respond!
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
