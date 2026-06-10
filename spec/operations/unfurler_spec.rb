require "rails_helper"

RSpec.describe Unfurler do
  describe "#perform" do
    it "routes YouTube watch URLs to Unfurler::Youtube" do
      expect(Unfurler::Youtube).to receive(:new).with("abc123").and_return(
        double(perform: Unfurler::Result.new("u", "t", "d", "i", "a", "UC", false, nil, {}))
      )
      described_class.new("https://www.youtube.com/watch?v=abc123").perform
    end

    it "routes YouTube Shorts URLs to Unfurler::Youtube (not Html)" do
      expect(Unfurler::Html).not_to receive(:new)
      expect(Unfurler::Youtube).to receive(:new).with("short42").and_return(
        double(perform: Unfurler::Result.new("u", "t", "d", "i", "a", "UC", true, nil, {}))
      )
      described_class.new("https://www.youtube.com/shorts/short42").perform
    end

    it "routes youtu.be URLs to Unfurler::Youtube" do
      expect(Unfurler::Youtube).to receive(:new).with("xyz789").and_return(
        double(perform: Unfurler::Result.new("u", "t", "d", "i", "a", "UC", false, nil, {}))
      )
      described_class.new("https://youtu.be/xyz789").perform
    end

    it "does not route notyoutube.com to Unfurler::Youtube" do
      expect(Unfurler::Youtube).not_to receive(:new)
      stub_request(:get, "https://notyoutube.com/watch?v=abc").to_return(
        body: "<html><head><title>x</title></head></html>"
      )
      described_class.new("https://notyoutube.com/watch?v=abc").perform
    end

    it "refuses to fetch URLs whose host resolves to a private address (SSRF regression)" do
      allow(Resolv).to receive(:getaddresses).with("metadata.internal").and_return(
        ["169.254.169.254"]
      )

      expect { described_class.new("http://metadata.internal/latest/").perform }.to raise_error(
        Faraday::Error
      )
    end

    it "refuses to fetch loopback URLs (SSRF regression)" do
      expect { described_class.new("http://127.0.0.1:6379/").perform }.to raise_error(
        Faraday::Error
      )
    end
  end
end
