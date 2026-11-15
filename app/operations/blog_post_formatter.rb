class BlogPostFormatter < FpcFormatter
  STRIPPED_ATTRIBUTES = %w[style].freeze

  def transformers
    []
  end

  private

  def stripped_attributes
    STRIPPED_ATTRIBUTES
  end
end
