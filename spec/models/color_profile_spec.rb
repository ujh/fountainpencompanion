require "rails_helper"

describe ColorProfile do
  describe ".from_hex" do
    describe "families, lightness and saturation" do
      [
        ["#ff0000", { family: "red", secondary_family: nil, saturation: "vivid" }],
        ["#ffa500", { family: "orange", secondary_family: "yellow", lightness: "light" }],
        ["#ffff00", { family: "yellow", secondary_family: nil, lightness: "light" }],
        ["#008000", { family: "green", secondary_family: nil, lightness: "medium" }],
        ["#008080", { family: "teal", secondary_family: "blue" }],
        ["#0000ff", { family: "blue", secondary_family: nil, saturation: "vivid" }],
        ["#800080", { family: "purple", secondary_family: nil, lightness: "dark" }],
        ["#ff69b4", { family: "pink", secondary_family: nil, lightness: "light" }],
        ["#704214", { family: "brown", secondary_family: "orange" }],
        ["#808080", { family: "gray", secondary_family: nil }],
        ["#000000", { family: "black", secondary_family: nil }]
      ].each do |hex, expected|
        it "reads #{hex}" do
          expect(described_class.from_hex(hex)).to have_attributes(expected)
        end
      end
    end

    describe "blue-blacks" do
      [
        ["#1b2233", { family: "black", secondary_family: "blue", lightness: "dark" }],
        ["#2b3a4f", { family: "blue", secondary_family: "black", lightness: "dark" }],
        ["#1a2a5a", { family: "blue", secondary_family: "black", saturation: "muted" }],
        ["#000080", { family: "blue", secondary_family: "black", saturation: "vivid" }],
        ["#3b4a5a", { family: "blue", secondary_family: "gray" }]
      ].each do |hex, expected|
        it "reads #{hex} as a blue-black" do
          expect(described_class.from_hex(hex)).to have_attributes(expected)
        end
      end
    end

    describe "teals" do
      [
        ["#20b2aa", { family: "teal", secondary_family: "green" }],
        ["#40e0d0", { family: "teal", secondary_family: "green", lightness: "light" }],
        ["#23737a", { family: "teal", secondary_family: "blue" }],
        ["#1e7c52", { family: "green", secondary_family: "teal" }]
      ].each do |hex, expected|
        it "reads #{hex}" do
          expect(described_class.from_hex(hex)).to have_attributes(expected)
        end
      end
    end

    describe "reds, burgundies and pinks" do
      [
        ["#800020", { family: "red", secondary_family: "purple", lightness: "dark" }],
        ["#722f37", { family: "red", secondary_family: "brown", lightness: "dark" }],
        ["#4a0000", { family: "red", secondary_family: "brown", lightness: "dark" }],
        ["#ea5531", { family: "red", secondary_family: "orange" }],
        ["#c06c75", { family: "red", secondary_family: "pink", saturation: "muted" }],
        ["#d02769", { family: "pink", secondary_family: "red" }],
        ["#ffc0cb", { family: "pink", secondary_family: "red", saturation: "muted" }],
        ["#c71585", { family: "pink", secondary_family: "purple" }],
        ["#6b1f4f", { family: "purple", secondary_family: "pink", lightness: "dark" }],
        ["#6b3a3a", { family: "brown", secondary_family: "red", lightness: "dark" }],
        ["#8a5a5a", { family: "brown", secondary_family: "red", lightness: "medium" }],
        ["#ff00ff", { family: "purple", secondary_family: "pink" }]
      ].each do |hex, expected|
        it "reads #{hex}" do
          expect(described_class.from_hex(hex)).to have_attributes(expected)
        end
      end
    end

    describe "sepias and browns" do
      [
        ["#704214", { family: "brown", secondary_family: "orange", lightness: "dark" }],
        ["#ae6928", { family: "brown", secondary_family: "orange", lightness: "medium" }],
        ["#8b4513", { family: "brown", secondary_family: "orange" }],
        ["#d2b48c", { family: "brown", secondary_family: "orange", lightness: "light" }],
        ["#cc5500", { family: "brown", secondary_family: "orange", saturation: "vivid" }],
        ["#808000", { family: "green", secondary_family: "yellow" }],
        ["#6b631e", { family: "brown", secondary_family: "yellow", saturation: "muted" }],
        ["#6b671e", { family: "green", secondary_family: "yellow" }],
        ["#a39a6a", { family: "brown", secondary_family: "yellow", lightness: "medium" }],
        ["#9a925a", { family: "yellow", secondary_family: "brown", lightness: "medium" }],
        ["#b8860b", { family: "orange", secondary_family: "yellow" }]
      ].each do |hex, expected|
        it "reads #{hex}" do
          expect(described_class.from_hex(hex)).to have_attributes(expected)
        end
      end
    end

    describe "purples" do
      [
        ["#6a5acd", { family: "blue", secondary_family: "purple" }],
        ["#483d8b", { family: "blue", secondary_family: "purple", lightness: "dark" }],
        ["#4b0082", { family: "purple", secondary_family: "black" }]
      ].each do |hex, expected|
        it "reads #{hex}" do
          expect(described_class.from_hex(hex)).to have_attributes(expected)
        end
      end
    end

    describe "greys and near-blacks" do
      [
        ["#ffffff", { family: "gray", secondary_family: nil, lightness: "light" }],
        ["#d3d3d3", { family: "gray", secondary_family: nil, lightness: "light" }],
        ["#808080", { family: "gray", secondary_family: nil, lightness: "medium" }],
        ["#555555", { family: "gray", secondary_family: nil, saturation: "muted" }],
        ["#5f6b73", { family: "gray", secondary_family: "blue" }],
        ["#444444", { family: "black", secondary_family: "gray", lightness: "dark" }],
        ["#4a4a4a", { family: "gray", secondary_family: "black", lightness: "dark" }],
        ["#333333", { family: "black", secondary_family: nil }],
        ["#1a1a1a", { family: "black", secondary_family: nil }],
        ["#0d0d0d", { family: "black", secondary_family: nil }],
        ["#300a16", { family: "black", secondary_family: "red", lightness: "dark" }]
      ].each do |hex, expected|
        it "reads #{hex}" do
          expect(described_class.from_hex(hex)).to have_attributes(expected)
        end
      end
    end

    it "normalises short, upper-case and hash-less hex codes" do
      expect(described_class.from_hex(" #000 ")).to have_attributes(hex: "#000000", family: "black")
      expect(described_class.from_hex("1B2233")).to have_attributes(hex: "#1b2233", family: "black")
    end

    [nil, "", "  ", "blue", "#12345", "#gggggg"].each do |hex|
      it "returns an unknown profile for #{hex.inspect}" do
        profile = described_class.from_hex(hex)

        expect(profile).to have_attributes(
          hex: nil,
          family: nil,
          secondary_family: nil,
          lightness: nil,
          saturation: nil,
          known?: false,
          label: nil,
          families: []
        )
      end
    end

    it "only returns the listed families, lightnesses and saturations" do
      profiles = (0...4096).map { |index| described_class.from_hex(format("#%03x", index)) }

      expect(profiles.map(&:family).uniq).to match_array(described_class::FAMILIES)
      expect(profiles.map(&:secondary_family).compact.uniq - described_class::FAMILIES).to be_empty
      expect(profiles.map(&:lightness).uniq).to match_array(%w[light medium dark])
      expect(profiles.map(&:saturation).uniq).to match_array(%w[muted vivid])
      expect(profiles.select { |profile| profile.family == profile.secondary_family }).to be_empty
    end
  end

  describe "#label" do
    it "combines family and lightness" do
      expect(described_class.from_hex("#1a2a5a").label).to eq("blue, dark")
    end
  end

  describe "#matches?" do
    let(:teal) { described_class.from_hex("#23737a", tags: %w[darkslategray Shimmer navy]) }

    it "matches the primary family" do
      expect(teal.matches?("teal")).to be(true)
    end

    it "matches the secondary family" do
      expect(teal.matches?("blue")).to be(true)
    end

    it "matches a family named by a cluster CSS-colour tag" do
      expect(teal.matches?("gray")).to be(true)
    end

    it "does not match other families" do
      expect(teal.matches?("green")).to be(false)
      expect(teal.matches?("purple")).to be(false)
    end

    it "ignores case and surrounding whitespace in the requested family" do
      expect(teal.matches?(" Teal ")).to be(true)
    end

    it "does not match unknown family names" do
      expect(teal.matches?("white")).to be(false)
      expect(teal.matches?("shimmer")).to be(false)
      expect(teal.matches?(nil)).to be(false)
    end

    it "matches upper-case and blue-black tags" do
      profile = described_class.from_hex("#000000", tags: ["Blue-Black"])

      expect(profile.matches?("blue")).to be(true)
      expect(profile.matches?("black")).to be(true)
    end

    it "does not read colours from property tags" do
      profile = described_class.from_hex("#000000", tags: ["red sheen", "gold shimmer"])

      expect(profile.matches?("red")).to be(false)
      expect(profile.matches?("yellow")).to be(false)
    end

    it "gives near-white CSS tags no family" do
      profile = described_class.from_hex(nil, tags: %w[aliceblue ivory white])

      expect(described_class::FAMILIES.select { |family| profile.matches?(family) }).to be_empty
    end

    it "matches by tag when the colour is unknown" do
      profile = described_class.from_hex(nil, tags: ["midnightblue"])

      expect(profile.known?).to be(false)
      expect(profile.matches?("blue")).to be(true)
    end
  end

  describe "#matches_any?" do
    let(:profile) { described_class.from_hex("#704214") }

    it "matches when any requested family matches" do
      expect(profile.matches_any?(%w[blue orange])).to be(true)
    end

    it "does not match when no requested family matches" do
      expect(profile.matches_any?(%w[blue green])).to be(false)
      expect(profile.matches_any?([])).to be(false)
    end
  end

  describe "TAG_FAMILIES" do
    it "maps every CSS colour name the cluster tags are built from" do
      css_names = FindPrimaryColor::COLORS.keys + FindSecondaryColors::COLORS.keys

      expect(css_names - described_class::TAG_FAMILIES.keys).to be_empty
    end

    it "only maps to known families" do
      expect(
        described_class::TAG_FAMILIES.values.flatten.uniq - described_class::FAMILIES
      ).to be_empty
    end
  end

  describe ".for" do
    let(:macro_cluster) { create(:macro_cluster, color: "#1b2233", tags: %w[navy sheen]) }
    let(:micro_cluster) { create(:micro_cluster, macro_cluster:) }

    it "uses the ink's own colour and its cluster tags" do
      ink = create(:collected_ink, color: "#704214", micro_cluster:)

      expect(described_class.for(ink)).to have_attributes(
        hex: "#704214",
        family: "brown",
        tags: %w[navy sheen]
      )
      expect(described_class.for(ink).matches?("blue")).to be(true)
    end

    it "prefers the ink's own colour over the cluster colour" do
      ink = create(:collected_ink, color: "#704214", micro_cluster:)
      ink.update_column(:cluster_color, "#008000")

      expect(described_class.for(ink)).to have_attributes(hex: "#704214", family: "brown")
    end

    it "ignores the ink's own tags" do
      ink = create(:collected_ink, color: "#704214", micro_cluster:, tags_as_string: "red, pink")

      expect(ink.reload.tag_names).to match_array(%w[red pink])
      expect(described_class.for(ink).tags).to eq(%w[navy sheen])
      expect(described_class.for(ink).matches_any?(%w[red pink])).to be(false)
    end

    it "falls back to the cluster colour" do
      ink = create(:collected_ink, color: "", micro_cluster:)
      ink.update_column(:cluster_color, "#1b2233")

      expect(described_class.for(ink)).to have_attributes(hex: "#1b2233", family: "black")
    end

    it "falls back to the cluster colour when the ink's own colour is invalid" do
      ink = build(:collected_ink, color: "not a colour", cluster_color: "#008000")

      expect(described_class.for(ink)).to have_attributes(hex: "#008000", family: "green")
    end

    it "is unknown without a colour or a cluster" do
      ink = create(:collected_ink, color: "")

      expect(described_class.for(ink)).to have_attributes(known?: false, tags: [])
    end
  end
end
