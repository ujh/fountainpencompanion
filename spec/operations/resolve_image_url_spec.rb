require "rails_helper"

RSpec.describe ResolveImageUrl do
  describe "#perform" do
    it "returns nil for a blank URL" do
      expect(described_class.new("").perform).to be_nil
      expect(described_class.new(nil).perform).to be_nil
    end

    it "returns the URL when HEAD returns an image content-type" do
      url = "https://cdn.example.com/photo.jpg"
      stub_request(:head, url).to_return(status: 200, headers: { "Content-Type" => "image/jpeg" })

      expect(described_class.new(url).perform).to eq(url)
    end

    it "follows redirects and returns the final URL when it serves an image" do
      start_url = "https://example.com/og-image"
      final_url = "https://cdn.example.com/real.png"
      stub_request(:head, start_url).to_return(status: 301, headers: { "Location" => final_url })
      stub_request(:head, final_url).to_return(
        status: 200,
        headers: {
          "Content-Type" => "image/png"
        }
      )

      expect(described_class.new(start_url).perform).to eq(final_url)
    end

    it "returns nil when the redirect chain ends on a non-image response" do
      start_url = "https://example.com/maybe-image"
      final_url = "https://example.com/landing"
      stub_request(:head, start_url).to_return(status: 302, headers: { "Location" => final_url })
      stub_request(:head, final_url).to_return(
        status: 200,
        headers: {
          "Content-Type" => "text/html"
        }
      )

      expect(described_class.new(start_url).perform).to be_nil
    end

    it "returns nil when the redirect chain exceeds MAX_REDIRECTS" do
      urls = (0..described_class::MAX_REDIRECTS).map { |i| "https://example.com/r#{i}" }
      urls.each_with_index do |u, i|
        next_u = urls[i + 1] || "https://example.com/final"
        stub_request(:head, u).to_return(status: 301, headers: { "Location" => next_u })
      end

      expect(described_class.new(urls.first).perform).to be_nil
    end

    it "returns nil on a 404" do
      url = "https://example.com/missing"
      stub_request(:head, url).to_return(status: 404)

      expect(described_class.new(url).perform).to be_nil
    end

    it "returns nil on a connection failure" do
      url = "https://example.com/down"
      stub_request(:head, url).to_raise(Faraday::ConnectionFailed.new("nope"))

      expect(described_class.new(url).perform).to be_nil
    end

    it "returns nil for an invalid URL" do
      expect(described_class.new("not a url").perform).to be_nil
    end
  end
end
