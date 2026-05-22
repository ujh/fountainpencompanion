require "rails_helper"

RSpec.describe Youtube::VideoIdParser do
  describe ".parse" do
    it "extracts v= from a youtube.com URL" do
      expect(described_class.parse("https://www.youtube.com/watch?v=abc123")).to eq("abc123")
    end

    it "extracts the path id from a youtu.be URL" do
      expect(described_class.parse("https://youtu.be/xyz789")).to eq("xyz789")
    end

    it "extracts the shorts id from a youtube.com/shorts URL" do
      expect(described_class.parse("https://www.youtube.com/shorts/short42")).to eq("short42")
    end

    it "returns nil for non-YouTube hosts that happen to contain 'youtube.com'" do
      expect(described_class.parse("https://notyoutube.com/watch?v=abc")).to be_nil
    end

    it "returns nil for non-YouTube hosts that happen to contain 'youtu.be'" do
      expect(described_class.parse("https://youtu.beware.example/abc")).to be_nil
    end

    it "returns nil for invalid URIs" do
      expect(described_class.parse("not a url at all !!!")).to be_nil
    end

    it "is case-insensitive on the host" do
      expect(described_class.parse("https://WWW.YOUTUBE.COM/watch?v=abc123")).to eq("abc123")
    end
  end
end
