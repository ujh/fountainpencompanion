class BlogPostFormatter < FpcFormatter
  STRIPPED_ATTRIBUTES = %w[style].freeze

  private

  def stripped_attributes
    STRIPPED_ATTRIBUTES
  end
end
