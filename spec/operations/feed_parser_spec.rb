require "rails_helper"

describe FeedParser do
  def parse(body, feed_url = "https://blog.test/feed/")
    described_class.new(body, feed_url).perform
  end

  def atom(entries)
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Blog</title>
        <id>https://blog.test/</id>
        <updated>2026-11-01T00:00:00Z</updated>
        #{entries}
      </feed>
    XML
  end

  def rss(items)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Blog</title>
          <link>https://blog.test/</link>
          <description>d</description>
          #{items}
        </channel>
      </rss>
    XML
  end

  it "parses an RSS 2.0 feed" do
    items = parse(file_fixture("mountainofink.rss").read, "https://mountainofink.com/?format=rss")

    expect(items.length).to eq(20)
    expect(items.first).to eq(
      url: "https://mountainofink.com/blog/kobe-maya-lapis-lazuli",
      title: "Ink Review #1706: Kobe 14 Maya Lapis Lazuli",
      categories: ["Ink Review"]
    )
  end

  it "returns all categories of an RSS item" do
    items = parse(file_fixture("penaddict.rss").read, "https://penaddict.com/blog?format=rss")

    expect(items.first[:categories]).to eq(
      ["Pebble Stationery Co.", "Cosmo Air Light", "Notebook Reviews"]
    )
  end

  it "parses an Atom entry without an author" do
    items = parse(atom(<<~XML))
      <entry>
        <title>Pilot Kon-peki</title>
        <id>tag:blog.test,2026:1</id>
        <updated>2026-11-01T00:00:00Z</updated>
        <link href="https://blog.test/kon-peki"/>
        <category term="Inks"/>
      </entry>
    XML

    expect(items).to eq(
      [{ url: "https://blog.test/kon-peki", title: "Pilot Kon-peki", categories: ["Inks"] }]
    )
  end

  it "picks the HTML alternate link of an Atom entry with several links" do
    items = parse(atom(<<~XML))
      <entry>
        <title>Blogger post</title>
        <link rel="replies" type="application/atom+xml" href="https://blog.test/feeds/1/comments"/>
        <link rel="replies" type="text/html" href="https://blog.test/post.html#comments"/>
        <link rel="edit" type="application/atom+xml" href="https://blog.test/feeds/posts/1"/>
        <link rel="alternate" type="text/html" href="https://blog.test/post.html"/>
      </entry>
    XML

    expect(items.map { |item| item[:url] }).to eq(["https://blog.test/post.html"])
  end

  it "picks the alternate link of an Atom entry when it has no type" do
    items = parse(atom(<<~XML))
      <entry>
        <title>Post</title>
        <link rel="replies" href="https://blog.test/post#comments"/>
        <link rel="alternate" href="https://blog.test/post"/>
      </entry>
    XML

    expect(items.map { |item| item[:url] }).to eq(["https://blog.test/post"])
  end

  it "uses the original link of a FeedBurner Atom entry" do
    items = parse(<<~XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom" xmlns:feedburner="http://rssnamespace.org/feedburner/ext/1.0">
        <title>Blog</title>
        <link rel="alternate" type="text/html" href="https://blog.test/"/>
        <entry>
          <title>Post</title>
          <link rel="alternate" type="text/html" href="http://feedproxy.google.com/~r/Blog/~3/abc/post.html"/>
          <feedburner:origLink>https://blog.test/post.html</feedburner:origLink>
        </entry>
      </feed>
    XML

    expect(items.map { |item| item[:url] }).to eq(["https://blog.test/post.html"])
  end

  it "parses an RDF (RSS 1.0) feed" do
    items = parse(<<~XML)
      <?xml version="1.0"?>
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://purl.org/rss/1.0/">
        <channel rdf:about="https://blog.test/">
          <title>Blog</title>
          <link>https://blog.test/</link>
          <description>d</description>
        </channel>
        <item rdf:about="https://blog.test/sailor-yama-dori">
          <title>Sailor Yama-dori</title>
          <link>https://blog.test/sailor-yama-dori</link>
        </item>
      </rdf:RDF>
    XML

    expect(items).to eq(
      [{ url: "https://blog.test/sailor-yama-dori", title: "Sailor Yama-dori", categories: [] }]
    )
  end

  it "resolves relative entry URLs against the feed URL" do
    items = parse(rss(<<~XML), "https://blog.test/blog/feed/")
      <item><title>Root relative</title><link>/2026/kon-peki</link></item>
      <item><title>Path relative</title><link>iroshizuku</link></item>
    XML

    expect(items.map { |item| item[:url] }).to eq(
      %w[https://blog.test/2026/kon-peki https://blog.test/blog/feed/iroshizuku]
    )
  end

  it "drops entries whose relative URL cannot be resolved" do
    items = parse(rss(<<~XML))
      <item><title>Broken</title><link>%zz</link></item>
      <item><title>Fine</title><link>https://blog.test/fine</link></item>
    XML

    expect(items.map { |item| item[:title] }).to eq(["Fine"])
  end

  it "keeps absolute entry URLs as they are" do
    items = parse(rss("<item><title>T</title><link>https://Other.test/Post?a=1</link></item>"))

    expect(items.map { |item| item[:url] }).to eq(["https://Other.test/Post?a=1"])
  end

  it "drops entries without a URL" do
    items = parse(rss(<<~XML))
      <item><title>No link</title></item>
      <item><title>Blank link</title><link>  </link></item>
      <item><title>With link</title><link>https://blog.test/with-link</link></item>
    XML

    expect(items.map { |item| item[:title] }).to eq(["With link"])
  end

  it "drops entries whose URL is not http(s)" do
    items = parse(rss("<item><title>Mail</title><link>mailto:someone@blog.test</link></item>"))

    expect(items).to be_empty
  end

  it "strips whitespace from URLs, titles and categories" do
    items = parse(rss(<<~XML))
      <item>
        <title>
          Diamine Oxblood
        </title>
        <link>
          https://blog.test/oxblood
        </link>
        <category> Ink Reviews </category>
        <category>   </category>
      </item>
    XML

    expect(items).to eq(
      [{ url: "https://blog.test/oxblood", title: "Diamine Oxblood", categories: ["Ink Reviews"] }]
    )
  end

  it "reads a binary body as UTF-8" do
    body = rss("<item><title>Kon-peki – 紺碧</title><link>https://blog.test/k</link></item>").b

    expect(parse(body).first[:title]).to eq("Kon-peki – 紺碧")
  end

  it "removes NUL characters from titles and categories" do
    body = {
      version: "https://jsonfeed.org/version/1.1",
      title: "Blog",
      items: [
        { id: "1", url: "https://blog.test/nul", title: "Kon\u0000-peki", tags: ["In\u0000ks"] }
      ]
    }.to_json

    expect(parse(body)).to eq(
      [{ url: "https://blog.test/nul", title: "Kon-peki", categories: ["Inks"] }]
    )
  end

  it "raises FeedParser::Error for input that is not a feed" do
    expect { parse("<html><body>Not a feed</body></html>") }.to raise_error(FeedParser::Error)
  end

  it "raises FeedParser::Error for an empty body" do
    expect { parse("") }.to raise_error(FeedParser::Error)
  end

  it "raises FeedParser::Error for a broken JSON feed" do
    expect { parse('{"version": "https://jsonfeed.org/version/1", ') }.to raise_error(
      FeedParser::Error
    )
  end
end
