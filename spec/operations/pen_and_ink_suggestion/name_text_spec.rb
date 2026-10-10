require "rails_helper"

RSpec.describe PenAndInkSuggestion::NameText do
  describe ".tokens" do
    it "splits on anything that is not a letter or digit, lowercases and drops accents" do
      expect(described_class.words("Pelikan Souverän M800, Kon-peki!")).to eq(
        %w[pelikan souveran m800 kon peki]
      )
    end

    it "keeps the position of each word in the original text" do
      text = "ink for the Asvine V-128"
      token = described_class.tokens(text).last

      expect(text[token.start...token.stop]).to eq("128")
    end

    it "keeps non-Latin words" do
      expect(described_class.words("色彩雫 Ku-jaku")).to eq(%w[色彩雫 ku jaku])
    end
  end

  describe ".same_word?" do
    it "allows one edit between alphabetic words of five or more letters" do
      expect(described_class.same_word?("murakuro", "murakumo")).to be(true)
      expect(described_class.same_word?("kweco", "kaweco")).to be(true)
      expect(described_class.same_word?("glauko", "glauco")).to be(true)
    end

    it "wants an exact match for short words and for words with digits" do
      expect(described_class.same_word?("lamy", "lamz")).to be(false)
      expect(described_class.same_word?("v128", "v126")).to be(false)
      expect(described_class.same_word?("custom743", "custom742")).to be(false)
    end

    it "does not allow two edits" do
      expect(described_class.same_word?("visconti", "visconit")).to be(false)
    end
  end

  describe ".distance" do
    it "counts insertions, deletions and substitutions" do
      expect(described_class.distance("v128", "v126")).to eq(1)
      expect(described_class.distance("kitten", "sitting")).to eq(3)
      expect(described_class.distance("", "abc")).to eq(3)
    end
  end
end
