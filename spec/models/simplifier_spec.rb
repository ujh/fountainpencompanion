require 'rails_helper'

describe Simplifier do
  describe "#simplify" do

    it "transliterates umlauts" do
      expect(described_class.simplify("ä")).to eq("a")
    end

    it "removes stuff in brackets" do
      expect(described_class.simplify("some (thing)")).to eq("some")
    end

    it "replaces ampersand with and" do
      expect(described_class.simplify("Rohrer & Klingner")).to eq("rohrerandklingner")
    end

    it "removes hashtags with numbers at the beginning" do
      expect(described_class.simplify("#8 Diep-Duinwaterblauw")).to eq("diepduinwaterblauw")
    end

    it "removes numbers at the beginning" do
      expect(described_class.simplify("05 Shocking Blue")).to eq("shockingblue")
    end

    it "removes stuff in quotes at the end" do
      expect(described_class.simplify('something "bla"')).to eq("something")
    end

    it "remove stuff in quotes in the middle" do
      expect(described_class.simplify('something "bla" else')).to eq("somethingelse")
    end

    it "removes no. N at the beginning" do
      expect(described_class.simplify("No. 5 Shocking Blue")).to eq("shockingblue")
    end

    it "removes initials" do
      expect(described_class.simplify("P.W. Akkerman")).to eq("akkerman")
    end

    it "does not remove initials in the middle" do
      expect(described_class.simplify("XX P.W. Akkerman")).to eq("xxpwakkerman")
    end

    it "only keeps letters and numbers" do
      expect(described_class.simplify("Abc123,.;")).to eq("abc123")
    end

    it "downcases the string" do
      expect(described_class.simplify("ABc")).to eq("abc")
    end
  end
end
