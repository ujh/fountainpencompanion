require "rails_helper"
require "active_record/testing/query_assertions"

RSpec.describe PenAndInkSuggestion::MentionMatcher do
  include RSpec::Rails::MinitestAssertionAdapter
  include ActiveSupport::Testing::Assertions
  include ActiveRecord::Assertions::QueryAssertions

  let(:user) { create(:user) }

  def snapshot
    PenAndInkSuggestion::CollectionSnapshot.new(user)
  end

  def mentions_for(text)
    described_class.call(PenAndInkSuggestion::NameIndex.for(snapshot), text)
  end

  def pins_for(text)
    current = snapshot
    index = PenAndInkSuggestion::NameIndex.for(current)
    resolution =
      PenAndInkSuggestion::NameResolver.call(current, described_class.call(index, text), index:)
    resolution.pen_pins + resolution.ink_pins
  end

  def pen(brand, model, **attributes)
    create(:collected_pen, user:, brand:, model:, **attributes)
  end

  def ink(brand, name, line: "", **attributes)
    create(:collected_ink, user:, brand_name: brand, line_name: line, ink_name: name, **attributes)
  end

  describe "brand and model" do
    let!(:lamy_2000) { pen("Lamy", "2000") }
    let!(:safari) { pen("Lamy", "Safari") }

    it "pins a pen named by brand and model" do
      expect(mentions_for("Lamy 2000 with something dark")).to eq(
        [described_class::Mention.new(text: "Lamy 2000", side: :pen)]
      )
      expect(pins_for("Lamy 2000 with something dark")).to eq([lamy_2000])
    end

    it "pins a pen named by brand and one word of a longer model" do
      kakuno = pen("Pilot Asia", "Kakuno - Baby")

      expect(pins_for("what goes into my pilot kakuno next")).to eq([kakuno])
    end

    it "pins an ink named by brand and name, or by line and name" do
      kon_peki = ink("Pilot", "Kon-peki", line: "Iroshizuku")

      expect(pins_for("a pen for Pilot Kon-peki")).to eq([kon_peki])
      expect(pins_for("a pen for iroshizuku konpeki")).to eq([kon_peki])
    end

    it "pins an ink whose name has a colour word when the brand is named" do
      velvet = ink("Diamine", "Blue Velvet")

      expect(pins_for("Diamine Blue Velvet please")).to eq([velvet])
    end

    it "pins the 3776 Century, not the other Platinum pen" do
      century = pen("Platinum", "3776 Century")
      pen("Platinum", "Preppy")

      expect(pins_for("3776 century")).to eq([century])
      expect(pins_for("my Platinum 3776 needs a refill")).to eq([century])
    end
  end

  describe "model or ink names of several words" do
    it "pins a model of two words without the brand" do
      custom = pen("Pilot", "Custom 743")
      pen("Pilot", "Custom 74")

      expect(pins_for("custom 743 again")).to eq([custom])
    end

    it "pins an ink name of two words without the brand" do
      crusoe = ink("Wearingeul", "Robinson Crusoe")

      expect(pins_for("a pen that suits Robinson Crusoe")).to eq([crusoe])
    end

    it "does not pin on one word of a name without the brand" do
      pen("Pilot", "Custom 743")

      expect(mentions_for("I want a custom grind for my next fill")).to be_empty
    end
  end

  describe "typos" do
    it "matches a word of five or more letters one edit away" do
      murakumo = ink("Sailor", "Murakumo", line: "Shikiori")

      expect(pins_for("Murakuro")).to eq([murakumo])
      expect(pins_for("a pen for Sailor Murakuro")).to eq([murakumo])
    end

    it "does not match model numbers one digit away" do
      pen("Pilot", "Custom 743")

      expect(pins_for("custom 742")).to be_empty
    end
  end

  describe "a brand followed by an unknown model code" do
    it "mentions it so the resolver can name the closest pen" do
      v126 = pen("Asvine", "V126")

      expect(mentions_for("ink for my Asvine V-128")).to eq(
        [described_class::Mention.new(text: "Asvine V-128", side: :pen)]
      )
      expect(pins_for("ink for my Asvine V-128")).to eq([v126])
    end
  end

  describe "bare names" do
    it "tries a bare name against pens and inks" do
      dandy_pen = pen("Scribo", "Feel Dandy")
      dandy_ink = ink("Kobe", "Dandy")

      expect(mentions_for("Dandy")).to eq([described_class::Mention.new(text: "Dandy", side: :any)])
      expect(pins_for("Dandy")).to contain_exactly(dandy_pen, dandy_ink)
    end

    it "pins a bare name only when it matches at most three items" do
      4.times { |i| ink("Kobe", "Dandy #{i + 1}") }

      expect(pins_for("Dandy")).to be_empty
    end

    it "pins a bare name only in a short instruction" do
      ink("Diamine", "Vibe", line: "Inkvent")

      expect(pins_for("ink for vibe")).to be_present
      expect(
        pins_for("Something cosy for rainy evenings with a vibe, pen and ink to match.")
      ).to be_empty
    end
  end

  describe "requests that name no item" do
    before do
      ink("Pelikan", "Black", line: "4001")
      ink("Diamine", "Green")
      ink("Lamy", "Blue", kind: "sample")
      pen("Kaweco", "Medium", nib: "M")
      ink("Sailor", "Sample")
    end

    [
      "Black ink",
      "medium nib",
      "green",
      "blue sample",
      "only samples",
      "a broad nib"
    ].each do |text|
      it "pins nothing for #{text.inspect}" do
        expect(pins_for(text)).to be_empty
      end
    end

    it "does not pin a brand on its own" do
      pen("Pilot", "Custom 74")
      pen("Pilot", "Prera")

      expect(mentions_for("one of my Pilots please")).to be_empty
      expect(mentions_for("Pilot")).to be_empty
    end

    it "never matches the pen colour or nib on their own" do
      pen("TWSBI", "Eco", color: "Cosmo Blue")

      expect(mentions_for("something for the cosmo blue one")).to be_empty
    end
  end

  describe "negation" do
    let!(:lamy_2000) { pen("Lamy", "2000") }
    let!(:kakuno) { pen("Pilot", "Kakuno") }

    it "does not pin a pen the request rules out" do
      expect(pins_for("not my Lamy 2000")).to be_empty
      expect(pins_for("something other than the Lamy 2000")).to be_empty
      expect(pins_for("I don't want the Lamy 2000")).to be_empty
      expect(pins_for("rainy mood, no pilot kakuno")).to be_empty
    end

    it "reads German and Spanish negations" do
      expect(pins_for("alles außer der Lamy 2000")).to be_empty
      expect(pins_for("sin la Pilot Kakuno")).to be_empty
    end

    it "does not let a negation reach into another clause" do
      expect(pins_for("Inking my Lamy 2000, but not with a shimmer ink")).to eq([lamy_2000])
      expect(pins_for("No shimmer. Use the Pilot Kakuno")).to eq([kakuno])
    end

    it "does not pin an ink the request uses as a reference" do
      ink("J. Herbin", "Perle Noire")

      expect(pins_for("something to complement my Herbin Perle Noire")).to be_empty
    end
  end

  describe "descriptions next to a name" do
    it "uses the colour and nib next to a name to choose among pens of that model" do
      matte = pen("Asvine", "V126", color: "Matte Black")
      frosted = pen("Asvine", "V126", color: "Frosted Black")
      ef = pen("Pelikan", "400NN", nib: "EF")
      pen("Pelikan", "400NN", nib: "B")

      expect(pins_for("the matte black Asvine V126 needs ink")).to eq([matte])
      expect(pins_for("fill the asvine v126 frosted black")).to eq([frosted])
      expect(pins_for("Refill a Pelikan 400nn, EF nib.")).to eq([ef])
    end

    it "takes the side from a following pen or ink word" do
      yumeyoi_pen = pen("PLUS x Sailor", "Yumeyoi Pro Gear Slim LE")
      ink("Plus x Sailor", "Yumeyoi")

      expect(mentions_for("what suits the Sailor Yumeyoi pen")).to eq(
        [described_class::Mention.new(text: "Sailor Yumeyoi", side: :pen)]
      )
      expect(pins_for("what suits the Sailor Yumeyoi pen")).to eq([yumeyoi_pen])
    end
  end

  it "finds several named items in one request" do
    lamy_2000 = pen("Lamy", "2000")
    conid = pen("Conid", "Bulkfiller Regular")

    expect(pins_for("first the Conid Bulkfiller Regular, then my Lamy 2000")).to eq(
      [conid, lamy_2000]
    )
  end

  it "matches and resolves from the loaded snapshot without further queries" do
    lamy = pen("Lamy", "2000")
    ink("Diamine", "Oxblood")
    create(:currently_inked, user:, collected_pen: lamy, collected_ink: ink("Pilot", "Kon-peki"))
    current = snapshot
    current.pens.each { |item| current.stats_for(item) }
    current.inks.each { |item| current.stats_for(item) }

    resolution = nil
    assert_queries_match(/SELECT/, count: 0) do
      index = PenAndInkSuggestion::NameIndex.for(current)
      mentions = described_class.call(index, "Lamy 2000 with Diamine Oxblood")
      resolution = PenAndInkSuggestion::NameResolver.call(current, mentions, index:)
    end

    expect(resolution.log_pins.size).to eq(2)
  end
end
