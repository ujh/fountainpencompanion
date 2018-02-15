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

    it "removes no. N at the beginning" do
      expect(described_class.simplify("No. 5 Shocking Blue")).to eq("shockingblue")
    end

    it "only keeps letters and numbers" do
      expect(described_class.simplify("123 Abc,.;")).to eq("123abc")
    end

    it "downcases the string" do
      expect(described_class.simplify("ABc")).to eq("abc")
    end
  end
end
