require "rails_helper"

RSpec.describe PenAndInkSuggestion::NameResolver do
  let(:user) { create(:user) }
  let(:today) { Date.current }

  def mention(text, side = :any)
    PenAndInkSuggestion::MentionMatcher::Mention.new(text:, side:)
  end

  def resolve(*mentions)
    described_class.call(PenAndInkSuggestion::CollectionSnapshot.new(user), mentions)
  end

  def pen(brand, model, **attributes)
    create(:collected_pen, user:, brand:, model:, **attributes)
  end

  def ink(brand, name, **attributes)
    create(:collected_ink, user:, brand_name: brand, ink_name: name, **attributes)
  end

  it "pins the best match and leaves out weaker ones" do
    custom_74 = pen("Pilot", "Custom 74")
    pen("Pilot", "Custom 743")

    resolution = resolve(mention("Pilot Custom 74", :pen))

    expect(resolution.pen_pins).to eq([custom_74])
    expect(resolution.ink_pins).to be_empty
    expect(resolution.notes).to be_empty
  end

  it "pins every item within 90% of the best score" do
    pro_gear = pen("Sailor", "Pro Gear")
    slim = pen("Sailor", "Pro Gear Slim")

    expect(resolve(mention("Pro Gear", :pen)).pen_pins).to contain_exactly(pro_gear, slim)
    expect(resolve(mention("Sailor Pro Gear Slim", :pen)).pen_pins).to eq([slim])
  end

  it "pins at most five of a tie, least recently used first" do
    ink = create(:collected_ink, user:)
    safaris = Array.new(7) { pen("Lamy", "Safari") }
    safaris
      .first(3)
      .each_with_index do |safari, i|
        create(
          :currently_inked,
          user:,
          collected_pen: safari,
          collected_ink: ink,
          inked_on: today - 30 + i,
          archived_on: today - 20 + i
        )
      end

    pins = resolve(mention("Lamy Safari", :pen)).pen_pins

    expect(pins.size).to eq(5)
    expect(pins.first(4)).to match_array(safaris.last(4))
    expect(pins.last).to eq(safaris.first)
  end

  it "tries a bare name against pens and inks" do
    dandy_pen = pen("Scribo", "Feel Dandy")
    dandy_ink = ink("Kobe", "Dandy")

    resolution = resolve(mention("Dandy"))

    expect(resolution.pen_pins).to eq([dandy_pen])
    expect(resolution.ink_pins).to eq([dandy_ink])
  end

  it "searches currently inked pens too" do
    inked = pen("Lamy", "2000")
    create(:currently_inked, user:, collected_pen: inked, collected_ink: ink("Diamine", "Oxblood"))

    expect(resolve(mention("Lamy 2000", :pen)).pen_pins).to eq([inked])
  end

  it "matches a typo of five or more letters" do
    murakumo = ink("Sailor", "Murakumo")

    expect(resolve(mention("Murakuro")).ink_pins).to eq([murakumo])
  end

  it "turns a brand on its own into a brand filter without pins" do
    custom = pen("Pilot", "Custom 74")
    prera = pen("Pilot", "Prera")
    pen("Lamy", "Safari")

    resolution = resolve(mention("Pilot", :pen))

    expect(resolution.pen_pins).to be_empty
    expect(resolution.pen_brand_filter).to contain_exactly(custom, prera)
    expect(resolution.notes).to be_empty
  end

  describe "a name that is not in the collection" do
    it "goes with the closest model of that brand and says so" do
      v126 = pen("Asvine", "V126")
      pen("Asvine", "P20")

      resolution = resolve(mention("Asvine V-128", :pen))

      expect(resolution.pen_pins).to eq([v126])
      expect(resolution.notes).to eq(
        [
          "I couldn't find \"Asvine V-128\" in your collection, so I went with the closest: " \
            "Asvine V126."
        ]
      )
    end

    it "pins nothing when no model of that brand is close" do
      pen("Platinum", "Preppy")

      resolution = resolve(mention("Platinum 3776", :pen))

      expect(resolution.pen_pins).to be_empty
      expect(resolution.notes).to eq(["I couldn't find \"Platinum 3776\" in your collection."])
    end

    it "does not count a model as named when the mention has a number it lacks" do
      pen("Pilot", "Custom 743")
      pen("Pilot", "Custom Heritage 912")

      resolution = resolve(mention("Pilot Custom 98", :pen))

      expect(resolution.pen_pins).to be_empty
      expect(resolution.notes).to eq(["I couldn't find \"Pilot Custom 98\" in your collection."])
    end

    it "keeps a number covered by the pen's colour or nib from blocking the name" do
      gold = pen("Pelikan", "M800", nib: "18k F")
      pen("Pelikan", "M800", nib: "EF")

      expect(resolve(mention("Pelikan M800 18k", :pen)).pen_pins).to eq([gold])
    end

    it "pins nothing when the brand is unknown too" do
      pen("Platinum", "Preppy")

      resolution = resolve(mention("Lamy 2000", :pen))

      expect(resolution.pen_pins).to be_empty
      expect(resolution.notes).to eq(["I couldn't find \"Lamy 2000\" in your collection."])
    end
  end

  it "leaves out a named pen that is not a fountain pen and a named swab, and says so" do
    pen("Jinhao", "82", nib: "Glass dip nib")
    ink("Diamine", "Oxblood", kind: "swab")

    resolution = resolve(mention("Jinhao 82", :pen), mention("Diamine Oxblood", :ink))

    expect(resolution.pen_pins).to be_empty
    expect(resolution.ink_pins).to be_empty
    expect(resolution.notes).to eq(
      [
        "I left out Jinhao 82: it isn't a fountain pen I can suggest an ink for.",
        "I left out Diamine Oxblood: a swab can't fill a pen."
      ]
    )
  end

  it "merges the pins of several mentions, at most five per side" do
    pens = %w[A B C D E F].map { |model| pen("Opus 88", "Model #{model}") }

    resolution = resolve(*pens.map { |item| mention("Opus 88 #{item.model}", :pen) })

    expect(resolution.pen_pins).to eq(pens.first(5))
  end

  it "only resolves the side a mention names" do
    pen("Sailor", "Yumeyoi")
    yumeyoi_ink = ink("Sailor", "Yumeyoi")

    resolution = resolve(mention("Sailor Yumeyoi", :ink))

    expect(resolution.pen_pins).to be_empty
    expect(resolution.ink_pins).to eq([yumeyoi_ink])
  end

  it "logs pins as pen and ink id hashes" do
    lamy = pen("Lamy", "2000")
    oxblood = ink("Diamine", "Oxblood")

    resolution = resolve(mention("Lamy 2000", :pen), mention("Diamine Oxblood", :ink))

    expect(resolution.log_pins).to eq([{ "pen_id" => lamy.id }, { "ink_id" => oxblood.id }])
    expect(resolution).to be_pins
    expect(described_class::Resolution.empty).not_to be_pins
  end

  it "never resolves another user's items" do
    create(:collected_pen, brand: "Lamy", model: "2000")

    expect(resolve(mention("Lamy 2000", :pen)).pen_pins).to be_empty
  end

  it "is empty without mentions" do
    expect(resolve).to eq(described_class::Resolution.empty)
  end
end
