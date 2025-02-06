require "rails_helper"

describe Simplifier do
  describe "#simplify" do
    it "transliterates umlauts" do
      expect(described_class.simplify("ä")).to eq("a")
    end

    it "does not remove stuff in brackets" do
      expect(described_class.simplify("some (thing)")).to eq("something")
    end

    it "replaces ampersand with and" do
      expect(described_class.simplify("Rohrer & Klingner")).to eq("rohrerandklingner")
    end

    it "replaces plus with and" do
      expect(described_class.simplify("Pen + Message")).to eq("penandmessage")
    end

    it "keeps numbers from hashtags with numbers at the beginning" do
      expect(described_class.simplify("#8 Diep-Duinwaterblauw")).to eq("8diepduinwaterblauw")
    end

    it "keeps numbers at the beginning" do
      expect(described_class.simplify("05 Shocking Blue")).to eq("05shockingblue")
      expect(described_class.simplify("1864 blue black")).to eq("1864blueblack")
    end

    it "does not remove stuff in quotes at the end" do
      expect(described_class.simplify('something "bla"')).to eq("somethingbla")
    end

    it "does not remove stuff in quotes in the middle" do
      expect(described_class.simplify('something "bla" else')).to eq("somethingblaelse")
    end

    it "removes no. N at the beginning" do
      expect(described_class.simplify("No. 5 Shocking Blue")).to eq("5shockingblue")
    end

    it "removes initials" do
      expect(described_class.simplify("P.W. Akkerman")).to eq("akkerman")
    end

    it "does not remove initials in the middle" do
      expect(described_class.simplify("XX P.W. Akkerman")).to eq("xxpwakkerman")
    end

    it "does not remove 3 or more initials" do
      expect(described_class.simplify("P.W.X. Akkerman")).to eq("pwxakkerman")
    end

    it "does not remove 4 initals" do
      expect(described_class.simplify("B.Y.O.B Pen Club")).to eq("byobpenclub")
    end

    it "only keeps letters and numbers" do
      expect(described_class.simplify("Abc123,.;")).to eq("abc123")
    end

    it "downcases the string" do
      expect(described_class.simplify("ABc")).to eq("abc")
    end

    it "leaves an entry alone that only consists of numbers" do
      expect(described_class.simplify("44")).to eq("44")
    end

    it "leaves an entry alone that has a number with a pound sign in front of it" do
      expect(described_class.simplify("#44")).to eq("44")
    end

    context "too short without numbers" do
      it "leaves numbers if name too short" do
        expect(described_class.simplify("23 - Guan")).to eq("23guan")
      end

      it "strips out the no." do
        expect(described_class.simplify("no. 23 - Guan")).to eq("23guan")
      end

      it "strips out the hash mark" do
        expect(described_class.simplify("#23 - Guan")).to eq("23guan")
      end
    end
  end
end
