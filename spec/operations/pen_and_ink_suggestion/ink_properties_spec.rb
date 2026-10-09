require "rails_helper"
require "active_record/testing/query_assertions"

describe PenAndInkSuggestion::InkProperties do
  include RSpec::Rails::MinitestAssertionAdapter
  include ActiveSupport::Testing::Assertions
  include ActiveRecord::Assertions::QueryAssertions

  describe ".from_texts" do
    describe "tags" do
      [
        ["shimmer", %w[shimmer]],
        ["#shimmer", %w[shimmer]],
        ["gold shimmer", %w[shimmer]],
        ["shimmering", %w[shimmer]],
        ["shimmering blue", %w[shimmer]],
        ["shimmer additive", %w[shimmer]],
        ["glitter potion", %w[shimmer]],
        ["sparkles", %w[shimmer]],
        ["pearlescent", %w[shimmer]],
        ["sheen", %w[sheen]],
        ["sheening", %w[sheen]],
        ["red sheen", %w[sheen]],
        ["low sheen", %w[sheen]],
        ["monster-sheen", %w[sheen]],
        ["shading", %w[shading]],
        ["low shading", %w[shading]],
        ["chromashading", %w[shading]],
        ["chromoshade", %w[shading]],
        ["multi-shader", %w[shading]],
        ["dual shading", %w[shading]],
        ["shade", %w[shading]],
        ["shade.m", %w[shading]],
        ["chameleon", %w[chameleon]],
        ["chameleon shimmer", %w[shimmer chameleon]],
        ["colour shifting", %w[chameleon]],
        ["colorshifting", %w[chameleon]],
        ["scented", %w[scented]],
        ["scent", %w[scented]],
        ["smells", %w[scented]],
        ["waterproof", %w[water-resistant]],
        ["water resistant", %w[water-resistant]],
        ["water-resistant", %w[water-resistant]],
        ["high-water-resistance", %w[water-resistant]],
        ["permanent", %w[water-resistant]],
        ["permanent ink", %w[water-resistant]],
        ["bulletproof", %w[water-resistant]],
        ["archival", %w[water-resistant]],
        ["pigment", %w[pigmented]],
        ["pigmented", %w[pigmented]],
        ["pigment based", %w[pigmented]],
        ["iron gall", ["iron gall"]],
        ["irongall", ["iron gall"]]
      ].each do |tag, labels|
        it "reads #{tag.inspect} as #{labels.join(", ")}" do
          expect(described_class.from_texts(tags: [tag]).labels).to eq(labels)
        end
      end

      [
        "no shimmer",
        "no-shimmer",
        "shimmer-free",
        "shimmer free",
        "shimmer_free",
        "shimmerless",
        "no glitter",
        "no sheen",
        "no–sheen",
        "no shading",
        "non-shading",
        "non-waterproof",
        "not water resistant",
        "notwaterproof",
        "low water resistance",
        "low-water-resistance",
        "partially waterproof",
        "semi-permanent",
        "waterman",
        "archive",
        "red pigment",
        "permanent black",
        "blue"
      ].each do |tag|
        it "reads #{tag.inspect} as no property" do
          expect(described_class.from_texts(tags: [tag])).to be_none
        end
      end
    end

    describe "descriptions" do
      [
        ["Sky blue with silver shimmer.", %w[shimmer]],
        ["Shimmery but doesn't clog EF pens", %w[shimmer]],
        ["A chameleon shimmer ink.", %w[shimmer chameleon]],
        ["Dark teal with Duochrome gold/pink shimmer.", %w[shimmer chameleon]],
        ["It is part of the Robert Oster shimmering ink range.", %w[shimmer]],
        ["It is full of shimmering particles.", %w[shimmer]],
        ["Shading and shimmering ink with a purple grey base.", %w[shimmer shading]],
        ["A deep blue, adorned with violet glitter.", %w[shimmer]],
        ["A blue-black ink with hints of bronze and red sheen. No shimmer.", %w[sheen]],
        ["Brighter blue. low shading, no sheen, and no shimmer.", %w[shading]],
        ["The inks are water soluble and shading, without shimmer or sheen.", %w[shading]],
        ["No sheen and gold shimmer.", %w[shimmer]],
        ["No sheen. Shimmer and shading.", %w[shimmer shading]],
        ["Low water resistance and shimmer.", %w[shimmer]],
        ["Not much sheen but lots of shimmer.", %w[shimmer]],
        ["Cool brown ink that shades nicely.", %w[shading]],
        ["It says it's not eternal, but it is certainly waterproof.", %w[water-resistant]],
        ["Medium water resistance.", %w[water-resistant]],
        ["Highly water resistant.", %w[water-resistant]],
        ["It is pH-neutral, is permanent and water-proof.", %w[water-resistant]],
        [
          "Permanent / Waterproof pigment ink suitable for fountain pens.",
          %w[water-resistant pigmented]
        ],
        ["A light brown ink, it has a caramel scent.", %w[scented]],
        ["It is lightly vanilla-scented.", %w[scented]],
        ["Sailor Sei-boku is a blue-black nano pigment ink with some sheen.", %w[sheen pigmented]],
        ["A pigment-based slightly pale red.", %w[pigmented]],
        ["Lovely blue black colour. This is an iron gall ink.", ["iron gall"]],
        ["Because it is an iron-gall ink, some care should be taken.", ["iron gall"]]
      ].each do |description, labels|
        it "reads #{description.inspect} as #{labels.join(", ")}" do
          expect(described_class.from_texts(descriptions: [description]).labels).to eq(labels)
        end
      end

      [
        "Shimmering blue.",
        "A shimmering blue like the sea at night.",
        "This sheen-free ink features a unique, shimmering effect where the ink pools.",
        "Purple-pink ink with no shimmer.",
        "Non-shimmering, pH neutral, grey-green.",
        "It doesn’t shimmer at all.",
        "Something that shines through like shimmer.",
        "No Yurameku ink has shimmer however.",
        "There is also a shimmer version.",
        "As with shimmer inks, it requires care to clean.",
        "You can even add some shimmer for extra pop!",
        "The night view of Kobe glitters like a jewel.",
        "The sparkling glints of light on the water.",
        "More of a very dark edging than any trace of sheen.",
        "Not water-resistant. No chroma-shading, no sheen, no shimmer.",
        "Without sheen and shimmer.",
        "No sheen, shading or shimmer.",
        "Not water-resistant, sheen, shading, or shimmer.",
        "Shimmer - No\r\nWater Resistance - No\r\nIron Gall - No\r\nPigment - No",
        "Sheen: none.",
        "This is not a permanent (water resistant) ink - not pigmented, and not iron gall.",
        "A lighter shade of blue.",
        "Low water resistance.",
        "Some water-resistance.",
        "It has a degree of water resistance.",
        "A golden brown from the Partially Bulletproof collection.",
        "The darker pools serve as a permanent reminder of stormier times.",
        "The garden is filled with the pleasant scent of lavender.",
        "A yellow-orange reminiscent of mango flesh.",
        "Smells",
        "The pigment was usually used as a glaze.",
        "A classic Waterman blue."
      ].each do |description|
        it "reads #{description.inspect} as no property" do
          expect(described_class.from_texts(descriptions: [description])).to be_none
        end
      end
    end

    describe "names" do
      [
        [["Diamine", "Shimmertastic", "Rockin Rio"], %w[shimmer]],
        [["Stationery Universe", "", "Midnight Morpho Shimmering"], %w[shimmer]],
        [["Robert Oster", "", "Sparkling Cranberry"], %w[shimmer]],
        [["De Atramentis", "Pearlescent", "Cyan Blue Gold"], %w[shimmer]],
        [["Monteverde", "", "Sheen Machine"], %w[sheen]],
        [["J. Herbin", "Scented", "Rose"], %w[scented]],
        [["Rohrer & Klingner", "", "Blau Permanent"], %w[water-resistant]],
        [["Kakimori", "Pigmented", "06 Toppuri"], %w[pigmented]],
        [["KWZ", "Iron Gall", "Turquoise"], ["iron gall"]]
      ].each do |names, labels|
        it "reads #{names.compact_blank.join(" ")} as #{labels.join(", ")}" do
          expect(described_class.from_texts(names:).labels).to eq(labels)
        end
      end

      [
        ["J. Herbin", "1670", "Bleu Ocean shimmerless"],
        ["Wearingeul", "Lee Yuk-sa", "Dizzy Scent of Maehwa"],
        ["Troublemaker", "", "Transcentral Highway"],
        ["Jungle", "", "Chameleon"],
        ["Diamine", "Inkvent 2021", "Night Shade"],
        ["Example", "", "Chromashading Blue"],
        ["Colorverse", "Office", "Permanent Black"]
      ].each do |names|
        it "reads #{names.compact_blank.join(" ")} as no property" do
          expect(described_class.from_texts(names:)).to be_none
        end
      end
    end

    it "flags a property when any source mentions it, even if another negates it" do
      properties =
        described_class.from_texts(
          tags: ["no shimmer"],
          descriptions: ["Blue with gold shimmer. No sheen."]
        )

      expect(properties.labels).to eq(%w[shimmer])
    end

    it "lists the properties in a fixed order" do
      properties =
        described_class.from_texts(tags: ["iron gall", "scented", "sheen", "shimmer", "pigment"])

      expect(properties.labels).to eq(["shimmer", "sheen", "scented", "pigmented", "iron gall"])
    end

    it "ignores blank and missing texts" do
      expect(
        described_class.from_texts(tags: ["", nil], names: [nil], descriptions: nil)
      ).to be_none
    end
  end

  describe "predicates" do
    subject(:properties) { described_class.new(%w[shimmer scented]) }

    it "answers each property" do
      expect(properties).to have_attributes(
        shimmer?: true,
        scented?: true,
        sheen?: false,
        shading?: false,
        chameleon?: false,
        water_resistant?: false,
        pigmented?: false,
        iron_gall?: false
      )
    end

    it "answers include? for symbols and strings" do
      expect(properties.include?(:shimmer)).to be(true)
      expect(properties.include?("scented")).to be(true)
      expect(properties.include?(:sheen)).to be(false)
    end

    it "drops unknown properties" do
      expect(described_class.new(%i[shimmer sparkle]).properties).to eq(%i[shimmer])
    end

    it "is none? without properties" do
      expect(described_class.new).to be_none
      expect(properties).not_to be_none
    end
  end

  describe ".for" do
    let(:macro_cluster) do
      create(
        :macro_cluster,
        tags: ["sheen"],
        description: "A dark blue with red sheen. It has some shading but no shimmer."
      )
    end
    let(:micro_cluster) { create(:micro_cluster, macro_cluster:) }

    it "combines the ink's own tags, its cluster tags, its names and the cluster description" do
      ink =
        create(
          :collected_ink,
          brand_name: "KWZ",
          line_name: "Iron Gall",
          ink_name: "Blue Black",
          tags_as_string: "scented",
          micro_cluster:
        )

      expect(described_class.for(ink.reload).labels).to eq(
        ["sheen", "shading", "scented", "iron gall"]
      )
    end

    it "reads the ink's own tags and names without a cluster" do
      ink = create(:collected_ink, line_name: "Shimmertastic", tags_as_string: "waterproof")

      expect(described_class.for(ink.reload).labels).to eq(%w[shimmer water-resistant])
    end

    it "makes no queries when tags and clusters are preloaded" do
      create(:collected_ink, tags_as_string: "shimmer", micro_cluster:)
      ink = CollectedInk.includes(:tags, micro_cluster: :macro_cluster).sole

      properties = nil
      assert_queries_match(/SELECT/, count: 0) { properties = described_class.for(ink) }

      expect(properties.labels).to eq(%w[shimmer sheen shading])
    end
  end
end
