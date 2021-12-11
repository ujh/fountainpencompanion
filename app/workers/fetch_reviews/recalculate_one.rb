class FetchReviews
  class RecalculateOne
    include Sidekiq::Worker

    def perform(ink_review_id)
      self.ink_review = InkReview.find(ink_review_id)
      ink_review.update!(
        title: title,
        description: description,
        image: image,
        author: author
      )
    end

    private

    attr_accessor :ink_review

    delegate :title, :description, :image, :author, to: :page_data

    def page_data
      @page_data ||= Unfurler.new(html).perform
    end

    def html
      connection = Faraday.new do |c|
        c.response :follow_redirects
        c.response :raise_error
      end
      connection.get(url_to_unfurl).body
    end

    def url_to_unfurl
      URI(ink_review.url)
    end
  end
end
