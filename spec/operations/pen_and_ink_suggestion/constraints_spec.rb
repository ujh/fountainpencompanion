require "rails_helper"

RSpec.describe PenAndInkSuggestion::Constraints do
  describe ".empty" do
    it "has every field at its default and no filters" do
      constraints = described_class.empty

      expect(constraints.to_h).to eq(
        "out_of_scope" => false,
        "requested_count" => 1,
        "keep_from_previous" => "none",
        "pair_usage" => "any",
        "soft_notes" => "",
        "pen" => {
          "mentions" => [],
          "exclude_mentions" => [],
          "comment_exclude" => [],
          "nib_grades_include" => [],
          "nib_grades_exclude" => [],
          "nib_width" => "any",
          "nib_characters_include" => [],
          "nib_characters_exclude" => [],
          "usage" => "any",
          "sort" => "default"
        },
        "ink" => {
          "mentions" => [],
          "exclude_mentions" => [],
          "tags_exclude" => [],
          "kinds_include" => [],
          "kinds_exclude" => [],
          "colour_include" => [],
          "colour_exclude" => [],
          "shimmer" => "any",
          "scented" => "any",
          "usage" => "any",
          "sort" => "default"
        }
      )
      expect(constraints.filters?).to be(false)
      expect(constraints).to eq(described_class.from_h({}))
    end
  end

  describe ".from_h" do
    it "keeps valid values, with string or symbol keys and any case" do
      constraints =
        described_class.from_h(
          "out_of_scope" => true,
          :requested_count => 3,
          "keep_from_previous" => "Pen",
          "pair_usage" => "new",
          "soft_notes" => "  autumn\n mood ",
          "pen" => {
            "nib_grades_include" => %w[m b],
            "nib_width" => "BROADISH",
            "nib_characters_exclude" => ["stub"],
            "usage" => "never_used",
            "sort" => "most_used"
          },
          :ink => {
            kinds_include: ["sample"],
            colour_exclude: %w[blue Gray],
            shimmer: "exclude",
            scented: "include"
          }
        )

      expect(constraints.out_of_scope).to be(true)
      expect(constraints.requested_count).to eq(3)
      expect(constraints.keep_from_previous).to eq("pen")
      expect(constraints.pair_usage).to eq("new")
      expect(constraints.soft_notes).to eq("autumn mood")
      expect(constraints.value("pen.nib_grades_include")).to eq(%w[M B])
      expect(constraints.value("pen.nib_width")).to eq("broadish")
      expect(constraints.value("pen.nib_characters_exclude")).to eq(["stub"])
      expect(constraints.value("pen.usage")).to eq("never_used")
      expect(constraints.value("pen.sort")).to eq("most_used")
      expect(constraints.value("ink.kinds_include")).to eq(["sample"])
      expect(constraints.value("ink.colour_exclude")).to eq(%w[blue gray])
      expect(constraints.value("ink.shimmer")).to eq("exclude")
      expect(constraints.value("ink.scented")).to eq("include")
    end

    it "drops unknown enum values and falls back to defaults" do
      constraints =
        described_class.from_h(
          "keep_from_previous" => "both",
          "pair_usage" => "sometimes",
          "pen" => {
            "nib_grades_include" => ["M", "XXL", 3, nil],
            "nib_width" => "chunky",
            "nib_characters_include" => %w[stub sparkly],
            "usage" => "rarely",
            "sort" => "random"
          },
          "ink" => {
            "kinds_include" => %w[sample swab],
            "colour_include" => %w[blue turquoise],
            "shimmer" => true,
            "scented" => "maybe"
          }
        )

      expect(constraints.keep_from_previous).to eq("none")
      expect(constraints.pair_usage).to eq("any")
      expect(constraints.value("pen.nib_grades_include")).to eq(["M"])
      expect(constraints.value("pen.nib_width")).to eq("any")
      expect(constraints.value("pen.nib_characters_include")).to eq(["stub"])
      expect(constraints.value("pen.usage")).to eq("any")
      expect(constraints.value("pen.sort")).to eq("default")
      expect(constraints.value("ink.kinds_include")).to eq(["sample"])
      expect(constraints.value("ink.colour_include")).to eq(["blue"])
      expect(constraints.value("ink.shimmer")).to eq("any")
      expect(constraints.value("ink.scented")).to eq("any")
    end

    it "caps lists and the length of every string" do
      long = "x" * 100
      constraints =
        described_class.from_h(
          "soft_notes" => "a" * 400,
          "pen" => {
            "mentions" => (1..8).map { |i| "Pen #{i}" },
            "exclude_mentions" => (1..12).map { |i| "Brand #{i}" },
            "comment_exclude" => %w[a b c d]
          },
          "ink" => {
            "mentions" => [long],
            "tags_exclude" => %w[a b c d e f]
          }
        )

      expect(constraints.soft_notes.length).to eq(300)
      expect(constraints.mentions(:pen)).to eq((1..5).map { |i| "Pen #{i}" })
      expect(constraints.value("pen.exclude_mentions").size).to eq(10)
      expect(constraints.value("pen.comment_exclude")).to eq(%w[a b c])
      expect(constraints.mentions(:ink)).to eq(["x" * 60])
      expect(constraints.value("ink.tags_exclude")).to eq(%w[a b c d e])
    end

    it "drops blank, duplicate and non-string terms" do
      constraints =
        described_class.from_h(
          "pen" => {
            "exclude_mentions" => ["Parker", " parker ", "Parker", "", 7, nil, { "x" => 1 }]
          },
          "ink" => {
            "mentions" => "Kon-peki"
          }
        )

      expect(constraints.value("pen.exclude_mentions")).to eq(["Parker"])
      expect(constraints.mentions(:ink)).to eq(["Kon-peki"])
    end

    it "accepts only true for out_of_scope and a positive count up to 10" do
      expect(described_class.from_h("out_of_scope" => "true").out_of_scope).to be(false)
      expect(described_class.from_h("requested_count" => 0).requested_count).to eq(1)
      expect(described_class.from_h("requested_count" => -2).requested_count).to eq(1)
      expect(described_class.from_h("requested_count" => 2.5).requested_count).to eq(1)
      expect(described_class.from_h("requested_count" => " 4 ").requested_count).to eq(4)
      expect(described_class.from_h("requested_count" => 50).requested_count).to eq(10)
    end

    it "ignores unknown fields, sides that are not mappings and input that is not a hash" do
      constraints =
        described_class.from_h(
          "colour" => "blue",
          "pen" => "Lamy",
          "ink" => {
            "exclude_ids" => [1],
            "colour_include" => ["red"]
          }
        )

      expect(constraints.to_h.keys).not_to include("colour")
      expect(constraints.to_h["ink"]).not_to have_key("exclude_ids")
      expect(constraints.value("ink.colour_include")).to eq(["red"])
      expect(constraints.value("pen.nib_width")).to eq("any")
      expect(described_class.from_h(nil)).to eq(described_class.empty)
      expect(described_class.from_h("text")).to eq(described_class.empty)
    end

    it "never takes the nib width slack from the input" do
      constraints =
        described_class.from_h("pen" => { "nib_width" => "fine", "nib_width_slack" => 1 })

      expect(constraints.nib_width_slack).to eq(0)
      expect(constraints.to_h["pen"]).not_to have_key("nib_width_slack")
    end

    it "returns a frozen value" do
      constraints = described_class.from_h("pen" => { "nib_grades_include" => ["M"] })

      expect(constraints.values).to be_frozen
      expect { constraints.value("pen.nib_grades_include") << "B" }.to raise_error(FrozenError)
    end
  end

  describe "filters" do
    it "lists the active exclusions and inclusions per side" do
      constraints =
        described_class.from_h(
          "pen" => {
            "exclude_mentions" => ["Parker"],
            "nib_width" => "fine",
            "sort" => "most_used",
            "mentions" => ["Lamy 2000"]
          },
          "ink" => {
            "colour_exclude" => ["blue"],
            "shimmer" => "exclude",
            "scented" => "include",
            "kinds_include" => ["sample"]
          }
        )

      expect(constraints.exclusions(:pen)).to eq(["pen.exclude_mentions"])
      expect(constraints.inclusions(:pen)).to eq(["pen.nib_width"])
      expect(constraints.exclusions(:ink)).to eq(%w[ink.colour_exclude ink.shimmer])
      expect(constraints.inclusions(:ink)).to eq(["ink.kinds_include"])
    end

    it "treats shimmer include as an inclusion and scented include as no filter" do
      constraints =
        described_class.from_h("ink" => { "shimmer" => "include", "scented" => "include" })

      expect(constraints.exclusions(:ink)).to be_empty
      expect(constraints.inclusions(:ink)).to eq(["ink.shimmer"])
    end

    it "has filters when a side or the pairing is constrained" do
      expect(described_class.from_h("pair_usage" => "new").filters?).to be(true)
      expect(described_class.from_h("pair_usage" => "new").filters?(:pen)).to be(false)
      expect(described_class.from_h("ink" => { "usage" => "never_used" }).filters?(:ink)).to be(
        true
      )
      expect(
        described_class.from_h(
          "out_of_scope" => true,
          "requested_count" => 2,
          "keep_from_previous" => "pen",
          "soft_notes" => "rainy day",
          "pen" => {
            "mentions" => ["Lamy"],
            "sort" => "least_recent"
          },
          "ink" => {
            "scented" => "include"
          }
        ).filters?
      ).to be(false)
    end
  end

  describe "copies" do
    let(:constraints) do
      described_class.from_h(
        "pair_usage" => "new",
        "pen" => {
          "nib_width" => "fine"
        },
        "ink" => {
          "colour_include" => ["blue"]
        }
      )
    end

    it "resets a field to its default without changing the original" do
      reset = constraints.reset("ink.colour_include").reset("pair_usage")

      expect(reset.value("ink.colour_include")).to eq([])
      expect(reset.pair_usage).to eq("any")
      expect(constraints.value("ink.colour_include")).to eq(["blue"])
      expect(constraints.pair_usage).to eq("new")
    end

    it "sets a value and the nib width slack, which a reset of the width clears" do
      widened = constraints.with("pen.nib_width", "fine", nib_width_slack: 1)

      expect(widened.nib_width_slack).to eq(1)
      expect(widened.to_h["pen"]["nib_width_slack"]).to eq(1)
      expect(widened).not_to eq(constraints)
      expect(widened.with("ink.colour_include", %w[blue teal]).nib_width_slack).to eq(1)
      expect(widened.reset("pen.nib_width").nib_width_slack).to eq(0)
    end
  end
end
