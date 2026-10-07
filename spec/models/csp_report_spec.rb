require "rails_helper"

describe CspReport do
  include ActiveSupport::Testing::TimeHelpers

  def report(overrides = {})
    {
      "document-uri" => "https://www.fountainpencompanion.com/brands",
      "effective-directive" => "script-src-elem",
      "violated-directive" => "script-src-elem",
      "blocked-uri" => "https://evil.example.com/tracker.js?id=1"
    }.merge(overrides)
  end

  describe ".record" do
    it "stores the directive, the blocked origin and the page's route" do
      described_class.record(report)

      csp_report = described_class.sole
      expect(csp_report).to have_attributes(
        directive: "script-src-elem",
        blocked_uri: "https://evil.example.com",
        page: "brands#index",
        count: 1
      )
    end

    it "counts repeated violations in a single row" do
      described_class.record(report)
      described_class.record(report("blocked-uri" => "https://evil.example.com/other.js"))

      expect(described_class.sole.count).to eq(2)
    end

    it "keeps the latest sample and last seen time" do
      described_class.record(report("source-file" => "https://www.fountainpencompanion.com/a.js"))
      travel 1.hour do
        described_class.record(report("source-file" => "https://www.fountainpencompanion.com/b.js"))
      end

      csp_report = described_class.sole
      expect(csp_report.sample).to eq("https://www.fountainpencompanion.com/b.js")
      expect(csp_report.updated_at).to be > csp_report.created_at
    end

    it "groups pages by route rather than by path" do
      described_class.record(report("document-uri" => "https://fpc.example/brands/1"))
      described_class.record(report("document-uri" => "https://fpc.example/brands/2"))

      expect(described_class.sole).to have_attributes(page: "brands#show", count: 2)
    end

    it "marks pages that match no route" do
      described_class.record(report("document-uri" => "https://fpc.example/nope/nope/nope"))

      expect(described_class.sole.page).to eq("unrecognized")
    end

    it "falls back to the violated directive" do
      described_class.record(
        report("effective-directive" => nil, "violated-directive" => "img-src https:")
      )

      expect(described_class.sole.directive).to eq("img-src")
    end

    it "keeps keyword sources such as inline scripts" do
      described_class.record(report("blocked-uri" => "inline", "script-sample" => "alert(1)"))

      expect(described_class.sole).to have_attributes(blocked_uri: "inline", sample: "alert(1)")
    end

    it "reduces scheme-only sources to their scheme" do
      described_class.record(report("blocked-uri" => "data:image/png;base64,AAAA"))

      expect(described_class.sole.blocked_uri).to eq("data:")
    end

    it "keeps non-default ports" do
      described_class.record(report("blocked-uri" => "http://localhost:3035/app.js"))

      expect(described_class.sole.blocked_uri).to eq("http://localhost:3035")
    end

    it "strips query strings and fragments from the source file" do
      described_class.record(
        report(
          "source-file" => "https://fpc.example/users/magic_link?user[token]=secret#x",
          "line-number" => 12
        )
      )

      expect(described_class.sole.sample).to eq("https://fpc.example/users/magic_link:12")
    end

    it "truncates long samples" do
      described_class.record(report("script-sample" => "x" * 1000))

      expect(described_class.sole.sample.length).to eq(CspReport::SAMPLE_LENGTH)
    end

    it "ignores violations caused by browser extensions" do
      described_class.record(report("blocked-uri" => "chrome-extension://abc/content.js"))
      described_class.record(
        report("blocked-uri" => "inline", "source-file" => "moz-extension://abc/x.js")
      )

      expect(described_class.count).to eq(0)
    end

    it "ignores unknown directives" do
      described_class.record(report("effective-directive" => "made-up-src"))

      expect(described_class.count).to eq(0)
    end

    it "ignores blocked URIs it cannot parse" do
      described_class.record(report("blocked-uri" => "https://exa mple.com/"))

      expect(described_class.count).to eq(0)
    end
  end
end
