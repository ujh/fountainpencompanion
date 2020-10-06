xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Fountain Pen Companion"
    xml.description "Announcements for Foutain Pen Companion"
    xml.link blog_index_path

    for post in @posts
      xml.item do
        xml.title post.title
        xml.description truncate(post.body, length: 500)
        xml.pubDate post.published_at.to_s(:rfc822)
        xml.link blog_url(post)
        xml.guid blog_url(post)
      end
    end
  end
end
