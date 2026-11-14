require "rails_helper"
require "active_record/testing/query_assertions"

describe ReviewFeedFilter do
  include RSpec::Rails::MinitestAssertionAdapter
  include ActiveSupport::Testing::Assertions
  include ActiveRecord::Assertions::QueryAssertions

  let(:brand_names) { ["Diamine", "Van Dieman's", "De Atramentis", "Pilot", "Sailor"] }
  let(:filter) { described_class.new(brand_names:) }

  def item(title: "", categories: [])
    { title:, categories: }
  end

  def match(**attributes)
    filter.match(item(**attributes))
  end

  def passes?(**attributes)
    filter.passes?(item(**attributes))
  end

  describe "category rule" do
    it "passes an item with an ink category" do
      expect(match(title: "Weekend notes", categories: %w[Pens Inks])).to eq(
        described_class::Match.new(rule: :category, text: "Inks")
      )
    end

    it "matches ink at a word start in the category, case-insensitively" do
      ["INK REVIEW", "Inks", "Ink Reviews", "Fountain Pen Inks", "Inkvent"].each do |category|
        expect(passes?(categories: [category])).to be(true)
      end
    end

    it "fails categories that only contain ink inside a word" do
      %w[Pink Links Thinking FountainPenInks].each do |category|
        expect(passes?(title: "Weekend notes", categories: [category])).to be(false)
      end
    end

    it "fails an item whose categories do not mention ink" do
      expect(passes?(title: "Weekend notes", categories: %w[Pens Paper])).to be(false)
    end

    it "handles missing categories" do
      expect(passes?(title: "Weekend notes", categories: nil)).to be(false)
      expect(filter.passes?({ title: "Weekend notes" })).to be(false)
    end
  end

  describe "brand rule" do
    it "passes a title containing a brand name" do
      expect(match(title: "Diamine Oxblood")).to eq(
        described_class::Match.new(rule: :brand, text: "Diamine")
      )
    end

    it "matches case-insensitively" do
      expect(match(title: "diamine oxblood").text).to eq("diamine")
      expect(match(title: "DIAMINE OXBLOOD").text).to eq("DIAMINE")
    end

    it "matches whole words only" do
      expect(passes?(title: "Diaminen und Pilotprojekte")).to be(false)
      expect(passes?(title: "Autopilot mode")).to be(false)
    end

    it "matches brand names next to punctuation" do
      expect(match(title: "Comparison: Sailor/Pilot blues").text).to eq("Sailor")
      expect(match(title: "(Diamine)").text).to eq("Diamine")
    end

    it "matches multi-word brands" do
      expect(match(title: "De Atramentis Document Black").text).to eq("De Atramentis")
      expect(match(title: "Van Dieman's Night Sky").text).to eq("Van Dieman's")
    end

    it "matches multi-word brands with other whitespace or a typographic apostrophe" do
      expect(match(title: "De  Atramentis Document Black").text).to eq("De  Atramentis")
      expect(match(title: "Van Dieman’s Night Sky").text).to eq("Van Dieman’s")
      expect(match(title: "De\u00A0Atramentis Document Black").text).to eq("De\u00A0Atramentis")
      expect(match(title: "De\u2009Atramentis Document Black").text).to eq("De\u2009Atramentis")
    end

    it "prefers the longest brand name" do
      filter = described_class.new(brand_names: ["Robert", "Robert Oster"])

      expect(filter.match(item(title: "Robert Oster Fire and Ice")).text).to eq("Robert Oster")
    end

    it "escapes regular expression characters in brand names" do
      filter = described_class.new(brand_names: ["Stylo+", "forme.", "Pen (Sketch)", "Push/Pull"])

      expect(filter.match(item(title: "Stylo+ blue")).text).to eq("Stylo+")
      expect(filter.match(item(title: "forme. Kamogawa")).text).to eq("forme.")
      expect(filter.match(item(title: "Pen (Sketch) black")).text).to eq("Pen (Sketch)")
      expect(filter.match(item(title: "Push/Pull green")).text).to eq("Push/Pull")
      expect(filter.passes?(item(title: "Styloo forme"))).to be(false)
    end

    it "ignores brand names shorter than three characters" do
      filter = described_class.new(brand_names: %w[GP Fe Ñ KWZ])

      expect(filter.passes?(item(title: "GP and Fe at the shop"))).to be(false)
      expect(filter.match(item(title: "KWZ Honey")).text).to eq("KWZ")
    end

    it "ignores brand names on the stoplist in any case" do
      filter = described_class.new(brand_names: %w[There ORIGINAL modern Cross Diamine])

      expect(filter.passes?(item(title: "There is the original modern cross"))).to be(false)
      expect(filter.match(item(title: "Cross and Diamine")).text).to eq("Diamine")
    end

    it "keeps pen brands that also make inks" do
      expect(match(title: "Pilot Custom 74").text).to eq("Pilot")
      expect(match(title: "Sailor Pro Gear").text).to eq("Sailor")
    end

    it "fails every title when there are no brand names" do
      filter = described_class.new(brand_names: [])

      expect(filter.passes?(item(title: "Diamine Oxblood"))).to be(false)
    end

    it "loads brand names and synonyms from brand clusters" do
      brand_cluster = create(:brand_cluster, name: "Wearingeul")
      create(:macro_cluster, brand_cluster:, brand_name: "Wearingeul")
      create(:macro_cluster, brand_cluster:, brand_name: "Wearingeul Ink Lab")
      create(:macro_cluster, brand_name: "Unassigned Brand")

      filter = described_class.new

      expect(filter.match(item(title: "Wearingeul Ink Lab Ophelia")).text).to eq(
        "Wearingeul Ink Lab"
      )
      expect(filter.match(item(title: "Wearingeul Ophelia")).text).to eq("Wearingeul")
      expect(filter.passes?(item(title: "Unassigned Brand Ophelia"))).to be(false)
    end

    it "loads brand cluster names and macro cluster brand names independently" do
      brand_cluster = create(:brand_cluster, name: "Kobe")
      create(:macro_cluster, brand_cluster:, brand_name: "Nagasawa")

      filter = described_class.new

      expect(filter.match(item(title: "Kobe #51 Rokko Green")).text).to eq("Kobe")
      expect(filter.match(item(title: "Nagasawa Sannomiya")).text).to eq("Nagasawa")
    end

    it "loads the brand names in two queries" do
      2.times do |n|
        brand_cluster = create(:brand_cluster)
        create_list(:macro_cluster, 2, brand_cluster:, brand_name: "Brand #{n}")
      end

      assert_queries_match(/SELECT/, count: 2) { described_class.new }
    end
  end

  describe "keyword rule" do
    it "passes titles with ink words" do
      %w[Ink inks Inky Inkvent Inked].each do |word|
        expect(match(title: "Weekend #{word} notes")).to eq(
          described_class::Match.new(rule: :keyword, text: "ink")
        )
      end
    end

    it "passes titles with swatch words" do
      expect(match(title: "Swatching blues").text).to eq("swatch")
      expect(match(title: "A SWATCH card").text).to eq("swatch")
    end

    it "fails review titles without a brand or an ink word" do
      expect(passes?(title: "A notebook Review")).to be(false)
      expect(passes?(title: "Reviewed: a pencil case")).to be(false)
    end

    it "fails words that only contain ink or swatch inside" do
      %w[pink think link drink Smartswatch].each do |word|
        expect(passes?(title: "A #{word} notebook")).to be(false)
      end
    end
  end

  describe "rule order" do
    it "reports the category before the brand and the brand before a keyword" do
      expect(match(title: "Diamine ink review", categories: ["Inks"]).rule).to eq(:category)
      expect(match(title: "Diamine ink review").rule).to eq(:brand)
    end
  end

  it "fails empty and blank titles" do
    expect(passes?(title: nil)).to be(false)
    expect(passes?(title: "")).to be(false)
    expect(passes?(title: "\u0000")).to be(false)
  end

  it "only looks at the start of very long titles" do
    expect(match(title: "Diamine #{"a" * 300_000}").text).to eq("Diamine")
    expect(passes?(title: "#{"word " * 300} Diamine Oxblood")).to be(false)
    expect(passes?(title: "#{"word " * 60_000} Diamine Oxblood")).to be(false)
  end

  it "only looks at the start of very long categories" do
    expect(passes?(categories: ["#{"word " * 300} Inks"])).to be(false)
  end

  it "matches across NUL characters" do
    expect(match(title: "\u0000Diamine\u0000 Oxblood").text).to eq("Diamine")
  end
end
