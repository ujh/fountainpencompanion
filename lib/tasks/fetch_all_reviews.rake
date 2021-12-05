namespace :fetch_all_reviews do
  desc "mountainofink.com"
  task mountainofink: :environment do
    url = base_url = 'https://mountainofink.com/'
    user = User.first
    loop do
      puts "Fetching #{url}"
      page_results, url = fetch_page(url, base_url)
      processed_results = page_results.map {|r| postprocess(r) }.compact
      puts "(#{processed_results.size} of #{page_results.size} found)\n"
      sleep rand(2)
      processed_results.each do |r|
        submission = CreateInkReviewSubmission.new(
          url: r.first,
          user: user,
          macro_cluster: r.last
        ).perform
      end
      break unless url
    end
  end

  private

  def fetch_page(url, base_url)
    document = Nokogiri::HTML(html(url))
    results = document.css('h1.entry-title').map do |element|
      link = element.at_css('a')
      [
        File.join(base_url, link['href']),
        link.inner_html
      ]
    end
    next_path = document.css('#nextLink')&.attribute('href')&.value
    next_url = if next_path
      File.join(base_url, next_path)
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
    search_term = entry.last.split(':').last.strip
    cluster = MacroCluster.full_text_search(entry).first
    if cluster
    entry + [cluster]
    else
      p entry
      nil
    end
  end
end
