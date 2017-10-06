require 'rails_helper'

describe Simplifier do
  describe "#simplify" do

    it "transliterates umlauts" do
      expect(described_class.simplify("ä")).to eq("a")
    end

    it "removes stuff in brackets" do
      expect(described_class.simplify("some (thing)")).to eq("some ")
    end
  end
end
