namespace :fetch_all_reviews do
  task wellappointeddesk: :environment do
    url = base_url = 'https://www.wellappointeddesk.com/category/ink-review/'
    user = User.first
    loop do
      puts "Fetching #{url}"
      page_results, url = fetch_page(url, base_url)
      processed_results = page_results.map do |r|
        puts "."
        sleep(2) # Less load on the the external website and the DB
        processed = postprocess(r)
        pp processed
        next unless processed
        CreateInkReviewSubmission.new(
          url: processed.first,
          user: user,
          macro_cluster: processed.last
        ).perform
      end.compact
      puts url
      puts "(#{processed_results.size} of #{page_results.size} found)\n"
      break unless url
    end
  end

  private

  def fetch_page(url, base_url)
    document = Nokogiri::HTML(html(url))
    results = document.css('article.post').map do |element|
      link = element.at_css('h2.entry-title a')
      [
        # File.join(base_url, link['href']),
        link['href'],
        link.inner_html.strip
      ]
    end
    # links = document.css('a.BlogList-pagination-link')
    # next_link = links.find {|link| link.at_css('span').inner_html.strip == 'Older' }
    # next_path = next_link&.attribute('href')&.value
    # next_url = if next_path
    #   File.join(base_url, next_path)
    # end
    next_url = begin
      document.at_css('a.next')['href']
    rescue
    end
    return [results, next_url]
  end

  def html(url)
    connection = Faraday.new do |c|
      c.response :follow_redirects
      c.response :raise_error
    end
    connection.get(url).body
  end

  def postprocess(entry)
    search_term = entry.last
    cluster = MacroCluster.full_text_search(search_term).first
    if cluster
    entry + [cluster]
    else
      p entry
      nil
    end
  end
end
