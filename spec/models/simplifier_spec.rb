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

    it "only keeps letters and numbers" do
      expect(described_class.simplify("123 Abc,.;")).to eq("123abc")
    end

    it "downcases the string" do
      expect(described_class.simplify("ABc")).to eq("abc")
    end
  end
end
