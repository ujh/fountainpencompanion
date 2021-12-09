class FetchReviews
  class MountainOfInk
    include Sidekiq::Worker

    def perform
      reviews = fetch_homepage
      processed_reviews = process_reviews(reviews)
      submit_reviews(processed_reviews)
    end

    private

    def submit_reviews(reviews)
      reviews.each do |review|
        CreateInkReviewSubmission.new(
          url: review[:url],
          user: user,
          macro_cluster: review[:macro_cluster]
        ).perform
      end
    end

    def process_reviews(reviews)
      reviews.each do |review|
        search_term = review[:title].split(':').last.strip
        cluster = MacroCluster.full_text_search(search_term).first
        review.merge(cluster: cluster)
      end
    end

    def fetch_homepage
      document = Nokogiri::HTML(html(url))
      document.css('h1.entry-title').map do |element|
        link = element.at_css('a')
        {
          url: File.join(url, link['href']),
          title: link.inner_html
        }
      end
    end

    def html(url)
      connection = Faraday.new do |c|
        c.response :follow_redirects
        c.response :raise_error
      end
      connection.get(url).body
    end

    def url
      'https://mountainofink.com/'
    end

    def user
      @user ||= User.find_by(email: Admin.first.email)
    end
  end
end
