require "rails_helper"

describe FpcFormatter do
  include ActiveSupport::Testing::TimeHelpers

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

  describe "class and id attributes" do
    it "strips a raw HTML full-page overlay built from Bootstrap utility classes" do
      html =
        '<div class="position-fixed top-0 start-0 w-100 vh-100 bg-body z-3">' \
          '<a class="stretched-link" href="https://evil.example"></a>' \
          '<h1 class="text-center mt-5" id="content">Session expired</h1></div>'
      output = render(html)
      expect(output).to include("<div>")
      expect(output).to include('<a href="https://evil.example"></a>')
      expect(output).to include("<h1>Session expired</h1>")
      expect(output).not_to include("class=")
      expect(output).not_to include("id=")
    end

    it "strips classes added through Kramdown inline attribute lists" do
      output = render("Session expired\n{: .position-fixed .vh-100 #overlay}")
      expect(output).to include("Session expired")
      expect(output).not_to include("class=")
      expect(output).not_to include("id=")
    end

    it "strips classes from spans" do
      output = render('<p><span class="multi">x</span></p>')
      expect(output).to include("<span>x</span>")
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

  describe "image-only paragraphs" do
    it "renders a YouTube watch URL as a figure without any HTTP request" do
      output = render("![Swab](https://www.youtube.com/watch?v=dQw4w9WgXcQ)")

      expect(output).to eq(
        '<figure><img src="https://www.youtube.com/watch?v=dQw4w9WgXcQ" alt="Swab"></figure>' + "\n"
      )
      expect(a_request(:any, /.*/)).not_to have_been_made
    end

    it "uses the image title as the figure caption" do
      output = render('![Swab](https://example.com/swab.jpg "Diamine Oxblood on Tomoe River")')

      expect(output).to eq(
        '<figure><img src="https://example.com/swab.jpg" alt="Swab" ' \
          'title="Diamine Oxblood on Tomoe River">' \
          "<figcaption>Diamine Oxblood on Tomoe River</figcaption></figure>\n"
      )
    end

    it "keeps an image inside running text in its paragraph" do
      output = render("Look: ![Swab](https://example.com/swab.jpg)")

      expect(output).to eq(
        '<p>Look: <img src="https://example.com/swab.jpg" alt="Swab"></p>' + "\n"
      )
    end
  end

  describe "rendering of typical descriptions" do
    it "autolinks bare URLs" do
      expect(render("More at https://example.com/ink.")).to eq(
        '<p>More at <a href="https://example.com/ink">https://example.com/ink</a>.</p>' + "\n"
      )
    end

    it "renders lists" do
      expect(render("Notes:\n\n* wet\n* shading\n")).to eq(
        "<p>Notes:</p>\n\n<ul>\n  <li>wet</li>\n  <li>shading</li>\n</ul>\n"
      )
    end

    it "renders emphasis" do
      expect(render("A *very* **dark** blue.")).to eq(
        "<p>A <em>very</em> <strong>dark</strong> blue.</p>\n"
      )
    end

    it "renders smart quotes and dashes" do
      expect(render(%(It's "blue-black" -- mostly...))).to eq(
        "<p>It’s “blue-black” – mostly…</p>\n"
      )
    end
  end

  describe "image sources" do
    def image_kept?(src)
      render(%(<p>Swab: <img src="#{src}" alt="swab"></p>)).include?("<img")
    end

    it "keeps images from external hosts" do
      expect(image_kept?("https://example.com/swab.jpg")).to be(true)
      expect(image_kept?("http://i.imgur.com/swab.jpg")).to be(true)
      expect(image_kept?("HTTPS://EXAMPLE.COM/swab.jpg")).to be(true)
    end

    it "keeps external markdown images" do
      output = render("![Swab](https://example.com/swab.jpg)")

      expect(output).to include('<img src="https://example.com/swab.jpg" alt="Swab">')
    end

    it "drops images from our own hosts" do
      Fountainpencompanion::HOSTS.each do |host|
        expect(image_kept?("https://#{host}/swab.jpg")).to be(false), host
        expect(image_kept?("http://#{host}:443/swab.jpg")).to be(false), host
      end
    end

    it "drops the figure of a dropped image-only paragraph" do
      expect(render("![Swab](https://fpc.ink/swab.jpg)")).not_to include("<figure")
    end

    it "keeps the caption of a dropped image" do
      expect(render('![Swab](https://fpc.ink/swab.jpg "Caption")')).to eq(
        "<figure><figcaption>Caption</figcaption></figure>\n"
      )
    end

    it "drops markdown images from our own hosts" do
      output = render("![Swab](https://www.fountainpencompanion.com/swab.jpg)")

      expect(output).not_to include("<img")
    end

    it "drops own hosts written in upper case or with a trailing dot" do
      expect(image_kept?("HTTPS://WWW.FOUNTAINPENCOMPANION.COM/swab.jpg")).to be(false)
      expect(image_kept?("https://fpc.ink./swab.jpg")).to be(false)
    end

    it "drops own hosts behind credentials, whitespace or percent-encoding" do
      expect(image_kept?("https://someone@fpc.ink/swab.jpg")).to be(false)
      expect(image_kept?(" https://fpc.ink/swab.jpg")).to be(false)
      expect(image_kept?("https://fpc%2Eink/swab.jpg")).to be(false)
    end

    it "drops relative and protocol-relative sources" do
      expect(image_kept?("/swab.jpg")).to be(false)
      expect(image_kept?("swab.jpg")).to be(false)
      expect(image_kept?("//fpc.ink/swab.jpg")).to be(false)
      expect(image_kept?("//example.com/swab.jpg")).to be(false)
    end

    it "drops sources with a malformed scheme separator" do
      expect(image_kept?("https:/fpc.ink/swab.jpg")).to be(false)
      expect(image_kept?("https:fpc.ink/swab.jpg")).to be(false)
      expect(image_kept?("https:\\\\fpc.ink\\swab.jpg")).to be(false)
    end

    it "drops sources that do not parse" do
      expect(image_kept?("https://example.com\\@fpc.ink/swab.jpg")).to be(false)
      expect(image_kept?("https://exa mple.com/swab.jpg")).to be(false)
    end

    it "drops images without a source" do
      expect(render('<p><img alt="swab"></p>')).not_to include("<img")
    end
  end

  describe "bracket nesting" do
    it "measures the deepest nesting of open brackets" do
      expect(described_class.bracket_depth("[a] [b [c]] [[[d]]]")).to eq(3)
    end

    it "counts brackets that are never closed" do
      expect(described_class.bracket_depth("[a [b [c")).to eq(3)
    end

    it "ignores closing brackets without an open one" do
      expect(described_class.bracket_depth("]]] [a]")).to eq(1)
    end

    it "renders markdown with brackets nested five deep" do
      expect(render("[[[[[*five*]]]]]")).to eq("<p>[[[[[<em>five</em>]]]]]</p>\n")
    end

    it "renders 5,000 characters of brackets nested five deep in well under a second" do
      sources = [
        ("[[[[[x]]]]] " * 500)[0, 5_000],
        ("[[[[ " + "[x] " * 1_250)[0, 5_000],
        ("[[[[[ " + "](x) " * 1_000)[0, 5_000],
        ("![x]( " * 1_000)[0, 5_000]
      ]

      sources.each do |source|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        render(source)
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
      end
    end

    it "renders deeper nesting as escaped plain text without parsing markdown" do
      expect(Kramdown::Document).not_to receive(:new)

      output = render("[[[[[[*six* <b>bold</b>\n\nnext")

      expect(output).to eq("<p>[[[[[[*six* &lt;b&gt;bold&lt;/b&gt;</p>\n\n<p>next</p>")
      expect(output).to be_html_safe
    end
  end

  describe "texts the renderer cannot handle" do
    it "renders escaped plain text when kramdown raises" do
      allow(Kramdown::Document).to receive(:new).and_raise(Kramdown::Error, "broken")

      expect(render("*a* <b>")).to eq("<p>*a* &lt;b&gt;</p>")
    end

    it "renders escaped plain text when the renderer needs a missing library" do
      source = %({::options transliterated_header_ids="true" auto_ids="true" /}\n\n# Héading)

      expect(render(source)).to eq(%(<p>#{source.lines.first.chomp}</p>\n\n<p># Héading</p>))
      expect(described_class.too_slow_to_render?(source)).to be(false)
    end

    it "renders deeply nested quotes as escaped plain text" do
      expect(render(">" * 5_000 + " quote")).to eq("<p>#{"&gt;" * 5_000} quote</p>")
    end

    it "renders deeply nested HTML as escaped plain text" do
      expect(render("<div>" * 1_000)).to eq("<p>#{"&lt;div&gt;" * 1_000}</p>")
    end
  end

  describe "slow texts" do
    include SlowMarkdownHelpers

    let(:slow_source) { SlowMarkdownHelpers::SLOW_MARKDOWN }

    before { make_markdown_slow }

    it "renders a text that takes too long as escaped plain text" do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect(render(slow_source)).to eq("<p>#{slow_source}</p>")
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
    end

    it "renders a slow text again on the next call" do
      render(slow_source)
      render(slow_source)

      expect(Kramdown::Document).to have_received(:new).twice
    end

    it "does not swallow an outer timeout" do
      stub_const("FpcFormatter::RENDER_TIMEOUT", 10)

      expect { Timeout.timeout(0.05) { render(slow_source) } }.to raise_error(Timeout::Error)
      expect do
        Timeout.timeout(0.05, Rack::Timeout::RequestTimeoutException) { render(slow_source) }
      end.to raise_error(Rack::Timeout::RequestTimeoutException)
    end

    it "reports which texts take too long" do
      expect(described_class.too_slow_to_render?(slow_source)).to be(true)
      expect(described_class.too_slow_to_render?("*quick*")).to be(false)
      expect(described_class.too_slow_to_render?("<div>" * 1_000)).to be(false)
    end
  end

  describe "caching" do
    it "renders a source only once" do
      expect(Kramdown::Document).to receive(:new).once.and_call_original

      first = render("*cached*")
      second = described_class.render("*cached*")

      expect(second).to eq(first)
      expect(second).to eq("<p><em>cached</em></p>\n")
      expect(second).to be_html_safe
    end

    it "renders again after a renderer error" do
      allow(Kramdown::Document).to receive(:new).and_raise(Kramdown::Error, "broken")
      expect(render("*a*")).to eq("<p>*a*</p>")
      allow(Kramdown::Document).to receive(:new).and_call_original

      expect(render("*a*")).to eq("<p><em>a</em></p>\n")
    end

    it "keeps the output of different formatters apart" do
      source = '<p class="lead">x</p>'

      expect(render(source)).to eq("<p>x</p>\n")
      expect(BlogPostFormatter.render(source).to_s).to eq(%(<p class="lead">x</p>\n))
      expect(render(source)).to eq("<p>x</p>\n")
    end

    it "renders again after the format version changes" do
      expect(Kramdown::Document).to receive(:new).twice.and_call_original

      render("*versioned*")
      stub_const("FpcFormatter::FORMAT_VERSION", FpcFormatter::FORMAT_VERSION + 1)
      render("*versioned*")
    end

    it "keeps rendered output for four weeks" do
      render("*kept*")

      travel(FpcFormatter::CACHE_EXPIRY - 1.minute)
      expect(Kramdown::Document).not_to receive(:new)
      render("*kept*")
    end

    it "renders again once rendered output expires" do
      render("*kept*")

      travel(FpcFormatter::CACHE_EXPIRY + 1.minute)
      expect(Kramdown::Document).to receive(:new).and_call_original
      render("*kept*")
    end

    it "does not cache the escaped text of deep nesting" do
      render("[[[[[[x")

      expect(described_class).to receive(:bracket_depth).and_call_original
      expect(render("[[[[[[x")).to eq("<p>[[[[[[x</p>")
    end

    it "uses the output of a successful timed check as the cached output" do
      expect(described_class.too_slow_to_render?("*checked*")).to be(false)

      expect(Kramdown::Document).not_to receive(:new)
      expect(render("*checked*")).to eq("<p><em>checked</em></p>\n")
    end

    it "does not cache markdown output for deeply nested texts from the timed check" do
      expect(described_class.too_slow_to_render?("[[[[[[*x*")).to be(false)

      expect(render("[[[[[[*x*")).to eq("<p>[[[[[[*x*</p>")
    end

    it "changes the cache key when the formatter source changes" do
      key = described_class.cache_key("x")
      stub_const("FpcFormatter::SOURCE_DIGEST", "changed")

      expect(described_class.cache_key("x")).not_to eq(key)
    end

    it "changes the cache key when a renderer gem changes" do
      %w[Sanitize Nokogiri Kramdown Rinku Slodown].each do |gem|
        key = described_class.cache_key("x")
        stub_const("#{gem}::VERSION", "0.0.0.test")

        expect(described_class.cache_key("x")).not_to eq(key), gem
      end
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
