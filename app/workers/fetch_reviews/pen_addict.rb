class FetchReviews
  class PenAddict
    include Sidekiq::Worker

    def perform
      reviews = fetch_homepage
      processed_reviews = process_reviews(reviews)
      submit_reviews(processed_reviews)
    end

    private

    def submit_reviews(reviews)
      reviews.each do |review|
        FetchReviews::SubmitReview.perform_async(
          review[:url],
          review[:macro_cluster]
        )
      end
    end

    def process_reviews(reviews)
      reviews.map do |review|
        search_term = review[:title].split(':').last.strip
        cluster = MacroCluster.full_text_search(search_term).first
        review.merge(cluster: cluster&.id)
      end
    end

    def fetch_homepage
      document = Nokogiri::HTML(html(url))
      document.css('h1.post-title').map do |element|
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
      'https://www.penaddict.com/'
    end
  end
end
