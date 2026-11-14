require "rails_helper"

describe DiscoverFeed do
  def discover(host: "blog.test", sample_urls: ["https://blog.test/2026/ink-review"])
    described_class.new(host:, sample_urls:).perform
  end

  def html(*links)
    "<html><head><title>Blog</title>#{links.join}</head><body><p>Post</p></body></html>"
  end

  def link_tag(href, type: "application/rss+xml", rel: "alternate", title: "Blog")
    %(<link rel="#{rel}" type="#{type}" title="#{title}" href="#{href}">)
  end

  def rss(*item_urls)
    items = item_urls.map { |url| "<item><title>Post</title><link>#{url}</link></item>" }
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0"><channel><title>Blog</title><link>https://blog.test/</link>
        <description>d</description>#{items.join}</channel></rss>
    XML
  end

  def atom(*entry_urls)
    entries =
      entry_urls.map do |url|
        "<entry><title>Post</title><id>#{url}</id><updated>2026-11-01T00:00:00Z</updated>" \
          "<link rel=\"alternate\" href=\"#{url}\"/></entry>"
      end
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom"><title>Blog</title><id>https://blog.test/</id>
        <updated>2026-11-01T00:00:00Z</updated>#{entries.join}</feed>
    XML
  end

  def stub_ok(url, body)
    stub_request(:get, url).to_return(status: 200, body:)
  end

  def stub_missing(*urls)
    urls.map { |url| stub_request(:get, url).to_return(status: 404) }
  end

  def stub_redirect(url, location)
    stub_request(:get, url).to_return(status: 301, headers: { "Location" => location })
  end

  def stub_no_fallbacks(root = "https://blog.test")
    stub_missing(*DiscoverFeed::FALLBACK_PATHS.map { |path| "#{root}#{path}" })
  end

  let(:blog_rss) { rss("https://blog.test/2026/a", "https://blog.test/2026/b") }

  it "finds the feed linked from the sample review page" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("https://blog.test/feed/")))
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "finds the feed linked only from the homepage" do
    stub_ok("https://blog.test/2026/ink-review", html)
    stub_ok("https://blog.test/", html(link_tag("https://blog.test/feed/")))
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "inspects the homepage when the sample page fails" do
    stub_request(:get, "https://blog.test/2026/ink-review").to_return(status: 500)
    stub_ok("https://blog.test/", html(link_tag("https://blog.test/feed/")))
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "resolves a relative feed link against the page URL" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("../feed.xml")))
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/feed.xml", blog_rss)

    expect(discover).to eq("https://blog.test/feed.xml")
  end

  it "resolves a relative feed link against the page URL after redirects" do
    stub_redirect("https://blog.test/2026/ink-review", "https://blog.test/posts/ink-review")
    stub_ok("https://blog.test/posts/ink-review", html(link_tag("feed")))
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/posts/feed", blog_rss)

    expect(discover).to eq("https://blog.test/posts/feed")
  end

  it "reads feed links with several rel tokens and any case" do
    stub_ok(
      "https://blog.test/2026/ink-review",
      html(link_tag("/feed/", rel: "Alternate home", type: "Application/RSS+XML"))
    )
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "ignores links that are not alternate feeds" do
    stub_ok(
      "https://blog.test/2026/ink-review",
      html(
        link_tag("/style.css", rel: "stylesheet", type: "text/css"),
        link_tag("/feed.json", type: "application/json"),
        link_tag("/feed/", rel: "preload")
      )
    )
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/atom.xml", atom("https://blog.test/2026/a"))
    stub_missing(
      *%w[/feed/ /?format=rss /feeds/posts/default?alt=rss /rss/].map { "https://blog.test#{_1}" }
    )

    expect(discover).to eq("https://blog.test/atom.xml")
  end

  it "skips comment feeds in favour of the posts feed" do
    comment_feeds = [
      stub_ok("https://blog.test/comments/feed/", blog_rss),
      stub_ok("https://blog.test/feeds/comments/default", blog_rss),
      stub_ok("https://blog.test/?feed=comments-rss2", blog_rss),
      stub_ok("https://blog.test/2026/ink-review/feed/", blog_rss)
    ]
    stub_ok(
      "https://blog.test/2026/ink-review",
      html(
        link_tag("/comments/feed/", title: "Blog » Comments Feed"),
        link_tag("/feeds/comments/default"),
        link_tag("/?feed=comments-rss2"),
        link_tag("/2026/ink-review/feed/", title: "Blog » Ink Review Comments Feed"),
        link_tag("/feed/", title: "Blog » Feed")
      )
    )
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
    comment_feeds.each { |stub| expect(stub).not_to have_been_requested }
  end

  it "skips the comment feed of the sample post whatever its title" do
    post_feed = stub_ok("https://blog.test/2026/ink-review/feed/", blog_rss)
    stub_ok(
      "https://blog.test/2026/ink-review/",
      html(link_tag("/2026/ink-review/feed/", title: "Blog » Revue d'encre Flux des commentaires"))
    )
    stub_ok("https://blog.test/", html(link_tag("/feed/")))
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover(sample_urls: ["https://blog.test/2026/ink-review/"])).to eq(
      "https://blog.test/feed/"
    )
    expect(post_feed).not_to have_been_requested
  end

  it "keeps the feed under the page the homepage redirected to" do
    stub_redirect("https://blog.test/", "https://blog.test/blog/")
    stub_ok("https://blog.test/blog/", html(link_tag("/blog/feed/")))
    stub_ok("https://blog.test/blog/feed/", blog_rss)

    expect(discover(sample_urls: [])).to eq("https://blog.test/blog/feed/")
  end

  it "keeps the feed under the redirected homepage when the sample page links none" do
    stub_ok("https://blog.test/2026/ink-review", html)
    stub_redirect("https://blog.test/", "https://blog.test/blog/")
    stub_ok("https://blog.test/blog/", html(link_tag("/blog/feed/")))
    stub_ok("https://blog.test/blog/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/blog/feed/")
  end

  it "ignores feed links that are not web URLs with a host" do
    allow(SafeHttp).to receive(:get).and_call_original
    stub_ok(
      "https://blog.test/2026/ink-review",
      html(
        link_tag("mailto:feeds@blog.test"),
        link_tag("https:///no-host.rss"),
        link_tag("http://exa mple.test/feed"),
        link_tag("/feed/")
      )
    )
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
    expect(SafeHttp).to have_received(:get).exactly(3).times
  end

  it "prefers the feed linked from the sample page over the one on the homepage" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("/feed/")))
    stub_ok("https://blog.test/", html(link_tag("/other.rss")))
    stub_ok("https://blog.test/feed/", blog_rss)
    other = stub_ok("https://blog.test/other.rss", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
    expect(other).not_to have_been_requested
  end

  it "accepts an Atom feed" do
    stub_ok(
      "https://blog.test/2026/ink-review",
      html(link_tag("/atom.xml", type: "application/atom+xml"))
    )
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/atom.xml", atom("https://blog.test/2026/a"))

    expect(discover).to eq("https://blog.test/atom.xml")
  end

  it "tries the WordPress feed path when no page links a feed" do
    stub_ok("https://blog.test/2026/ink-review", html)
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/feed/", blog_rss)
    later_paths = stub_missing("https://blog.test/?format=rss", "https://blog.test/rss/")

    expect(discover).to eq("https://blog.test/feed/")
    later_paths.each { |stub| expect(stub).not_to have_been_requested }
  end

  it "tries the Blogger feed path after paths that are missing or not feeds" do
    stub_ok("https://blog.test/2026/ink-review", html)
    stub_ok("https://blog.test/", html)
    stub_missing("https://blog.test/feed/")
    stub_ok("https://blog.test/?format=rss", html)
    stub_ok("https://blog.test/feeds/posts/default?alt=rss", blog_rss)

    expect(discover).to eq("https://blog.test/feeds/posts/default?alt=rss")
  end

  it "tries the fallback paths when the linked feeds fail" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("/posts.rss")))
    stub_ok("https://blog.test/", html)
    stub_missing("https://blog.test/posts.rss")
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "tries the fallback paths on the www host of a www-only site" do
    stub_ok("https://www.blog.test/2026/ink-review", html)
    stub_ok("https://www.blog.test/", html)
    stub_ok("https://www.blog.test/feed/", rss("https://www.blog.test/2026/a"))

    expect(discover(sample_urls: ["https://www.blog.test/2026/ink-review"])).to eq(
      "https://www.blog.test/feed/"
    )
  end

  it "tries the Jekyll and Hugo feed paths last" do
    stub_ok("https://blog.test/2026/ink-review", html)
    stub_ok("https://blog.test/", html)
    stub_missing(
      *%w[/feed/ /?format=rss /feeds/posts/default?alt=rss /rss/ /atom.xml /feed.xml].map do
        "https://blog.test#{_1}"
      end
    )
    stub_ok("https://blog.test/index.xml", blog_rss)

    expect(discover).to eq("https://blog.test/index.xml")
  end

  it "accepts a feed on another host whose items link to the blog" do
    stub_ok(
      "https://blog.test/2026/ink-review",
      html(link_tag("https://feeds.feedburner.com/BlogTest"))
    )
    stub_ok("https://blog.test/", html)
    stub_ok("https://feeds.feedburner.com/BlogTest", blog_rss)

    expect(discover).to eq("https://feeds.feedburner.com/BlogTest")
  end

  it "rejects a feed whose items link to another host and tries the next one" do
    stub_ok(
      "https://blog.test/2026/ink-review",
      html(link_tag("https://planet.test/feed/"), link_tag("/feed/"))
    )
    stub_ok("https://blog.test/", html)
    stub_ok("https://planet.test/feed/", rss("https://planet.test/a", "https://other.test/b"))
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "rejects a feed with only a minority of items on the blog" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("/links.rss"), link_tag("/feed/")))
    stub_ok("https://blog.test/", html)
    stub_ok(
      "https://blog.test/links.rss",
      rss("https://blog.test/2026/a", "https://other.test/b", "https://shop.test/c")
    )
    stub_ok(
      "https://blog.test/feed/",
      rss("https://blog.test/2026/a", "https://blog.test/2026/b", "https://shop.test/c")
    )

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "rejects a feed with exactly half of its items on the blog" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("/half.rss"), link_tag("/feed/")))
    stub_ok("https://blog.test/", html)
    stub_ok(
      "https://blog.test/half.rss",
      rss(
        "https://blog.test/2026/a",
        "https://blog.test/2026/b",
        "https://other.test/c",
        "https://shop.test/d"
      )
    )
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "rejects a feed without items" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("/empty.rss"), link_tag("/feed/")))
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/empty.rss", rss)
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "uses the www host of the sample URL for a www-only site" do
    stub_ok("https://www.blog.test/2026/ink-review", html)
    stub_ok("https://www.blog.test/", html(link_tag("/feed/")))
    stub_ok("https://www.blog.test/feed/", rss("https://www.blog.test/2026/a"))
    bare_homepage = stub_request(:get, "https://blog.test/")

    expect(discover(sample_urls: ["https://www.blog.test/2026/ink-review"])).to eq(
      "https://www.blog.test/feed/"
    )
    expect(bare_homepage).not_to have_been_requested
  end

  it "accepts a feed whose items are on the domain the homepage redirected to" do
    stub_redirect("https://old.test/", "https://new.test/")
    stub_ok("https://new.test/", html(link_tag("/feed/")))
    stub_ok("https://new.test/feed/", rss("https://new.test/2026/a", "https://new.test/2026/b"))

    expect(discover(host: "old.test", sample_urls: [])).to eq("https://new.test/feed/")
  end

  it "accepts a feed whose items are on the domain the sample page redirected to" do
    stub_redirect("https://old.test/2026/ink-review", "https://new.test/2026/ink-review")
    stub_ok("https://new.test/2026/ink-review", html(link_tag("/feed/")))
    stub_ok("https://old.test/", html)
    stub_ok("https://new.test/feed/", rss("https://new.test/2026/a"))

    expect(discover(host: "old.test", sample_urls: ["https://old.test/2026/ink-review"])).to eq(
      "https://new.test/feed/"
    )
  end

  it "returns the feed URL after redirects" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("http://blog.test/feed")))
    stub_ok("https://blog.test/", html)
    stub_redirect("http://blog.test/feed", "https://blog.test/feed/")
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "tries the next feed after a network error" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("/broken.rss"), link_tag("/feed/")))
    stub_ok("https://blog.test/", html)
    stub_request(:get, "https://blog.test/broken.rss").to_raise(SocketError)
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "tries the next feed after a timeout" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("/slow.rss"), link_tag("/feed/")))
    stub_ok("https://blog.test/", html)
    stub_request(:get, "https://blog.test/slow.rss").to_timeout
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "tries the next feed after a missing one" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("/old.rss"), link_tag("/feed/")))
    stub_ok("https://blog.test/", html)
    stub_missing("https://blog.test/old.rss")
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "skips a feed on an internal address without fetching it" do
    allow(Resolv).to receive(:getaddresses).with("internal.test").and_return(["10.0.0.7"])
    internal = stub_ok("http://internal.test/feed", blog_rss)
    stub_ok(
      "https://blog.test/2026/ink-review",
      html(link_tag("http://internal.test/feed"), link_tag("/feed/"))
    )
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
    expect(internal).not_to have_been_requested
  end

  it "tries the next feed after one that does not parse" do
    stub_ok("https://blog.test/2026/ink-review", html(link_tag("/garbage.rss"), link_tag("/feed/")))
    stub_ok("https://blog.test/", html)
    stub_ok("https://blog.test/garbage.rss", "not a feed")
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover).to eq("https://blog.test/feed/")
  end

  it "returns nil when no feed is found" do
    stub_ok("https://blog.test/2026/ink-review", html)
    stub_ok("https://blog.test/", html)
    stub_no_fallbacks

    expect(discover).to be_nil
  end

  it "returns nil when no page can be fetched" do
    stub_request(:get, "https://blog.test/2026/ink-review").to_raise(SocketError)
    stub_request(:get, "https://blog.test/").to_raise(SocketError)
    stub_no_fallbacks

    expect(discover).to be_nil
  end

  it "inspects https://<host>/ without sample URLs" do
    stub_ok("https://blog.test/", html(link_tag("/feed/")))
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover(sample_urls: [])).to eq("https://blog.test/feed/")
  end

  it "inspects https://<host>/ when the sample URL is not a web URL" do
    stub_ok("https://blog.test/", html(link_tag("/feed/")))
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover(sample_urls: ["mailto:someone@blog.test"])).to eq("https://blog.test/feed/")
  end

  it "inspects at most three sample pages" do
    samples = (1..4).map { |n| "https://blog.test/2026/review-#{n}" }
    samples.first(3).each { |url| stub_ok(url, html) }
    fourth = stub_ok(samples.last, html(link_tag("/feed/")))
    stub_ok("https://blog.test/", html(link_tag("/feed/")))
    stub_ok("https://blog.test/feed/", blog_rss)

    expect(discover(sample_urls: samples)).to eq("https://blog.test/feed/")
    expect(fourth).not_to have_been_requested
  end

  it "does not fetch the same URL twice" do
    samples = %w[https://blog.test/2026/a https://blog.test/2026/b https://blog.test/]
    page =
      html(
        link_tag("https://blog.test/"),
        link_tag("https://planet.test/feed/"),
        link_tag("https://blog.test/rss/")
      )
    pages = samples.map { |url| stub_ok(url, page) }
    planet = stub_ok("https://planet.test/feed/", rss("https://planet.test/a"))
    fallbacks = stub_no_fallbacks

    expect(discover(sample_urls: samples)).to be_nil
    (pages + fallbacks).each { |stub| expect(stub).to have_been_requested.once }
    expect(planet).to have_been_requested.once
  end

  it "stops after #{DiscoverFeed::MAX_FETCHES} fetches" do
    feeds = (1..15).map { |n| "https://planet.test/feed-#{n}.rss" }
    stub_ok("https://blog.test/2026/ink-review", html(*feeds.map { |url| link_tag(url) }))
    stub_ok("https://blog.test/", html)
    feeds.each { |url| stub_ok(url, rss("https://planet.test/a")) }

    expect(discover).to be_nil
    expect(a_request(:get, %r{\Ahttps://planet\.test/})).to have_been_made.times(10)
  end
end
