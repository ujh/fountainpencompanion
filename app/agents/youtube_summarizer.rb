class YoutubeSummarizer
  include RubyLlmAgent

  MODEL_ID = "gpt-4.1-mini"

  SYSTEM_DIRECTIVE = <<~TEXT
    You will be given a YouTube video's metadata: title, description, tags, top
    comments, captions (when available), and a thumbnail image. Summarize which
    fountain pen inks (if any) are reviewed in the video, what the reviewer
    says about each ink, and whether the video is a focused ink review or
    something else (unboxing, currently-inked, live stream, passing mention).
    Be concise and factual.
  TEXT

  def initialize(parent_agent_log, source)
    self.parent_agent_log = parent_agent_log
    self.source = source
  end

  def perform
    response = ask(prompt_text, with: resolved_image_url)
    agent_log.waiting_for_approval!
    response.content
  end

  def agent_log = find_or_create_agent_log(parent_agent_log)

  private

  attr_accessor :parent_agent_log, :source

  def prompt_text
    [
      "Title: #{source_title}",
      "Description: #{source_description}",
      "Tags: #{Array(source_tags).join(", ")}",
      "Top comments: #{format_comments(source_comments)}",
      "Captions: #{source_captions.presence || "(none available)"}"
    ].join("\n\n")
  end

  def format_comments(comments)
    return "(none)" if comments.blank?
    Array(comments)
      .first(3)
      .map { |c| "- #{c[:author] || c["author"]}: #{c[:text] || c["text"]}" }
      .join("\n")
  end

  def source_title = source.respond_to?(:title) ? source.title.to_s : ""
  def source_description = source.respond_to?(:description) ? source.description.to_s : ""
  def source_image = source.respond_to?(:image) ? source.image.to_s : ""

  def resolved_image_url
    ResolveImageUrl.new(source_image).perform
  end

  def source_tags
    if source.respond_to?(:youtube_tags)
      source.youtube_tags
    elsif source.respond_to?(:youtube)
      source.youtube&.[](:tags)
    end
  end

  def source_comments
    if source.respond_to?(:youtube_comments)
      source.youtube_comments
    elsif source.respond_to?(:youtube)
      source.youtube&.[](:comments)
    end
  end

  def source_captions
    if source.respond_to?(:youtube_captions)
      source.youtube_captions
    elsif source.respond_to?(:youtube)
      source.youtube&.[](:captions)
    end
  end
end
