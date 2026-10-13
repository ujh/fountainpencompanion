require "rails_helper"

RSpec.describe PenAndInkSuggestion::ConstraintCheck do
  let(:user) { create(:user) }
  let(:today) { Date.current }
  let(:snapshot) { PenAndInkSuggestion::CollectionSnapshot.new(user) }
  let(:check) { described_class.new(snapshot) }

  def constraints(hash)
    PenAndInkSuggestion::Constraints.from_h(hash)
  end

  def loaded(item)
    items = item.is_a?(CollectedPen) ? snapshot.pens : snapshot.inks
    items.find { |candidate| candidate.id == item.id }
  end

  def satisfies?(item, path, hash)
    check.satisfies?(loaded(item), path, constraints(hash))
  end

  def ink_it(pen, ink, inked_on: today - 20, archived_on: today - 10)
    create(:currently_inked, user:, collected_pen: pen, collected_ink: ink, inked_on:, archived_on:)
  end

  describe "pen constraints" do
    it "excludes mentions by whole words of brand and model, joined or with one typo" do
      parker = create(:collected_pen, user:, brand: "Parker", model: "51")
      custom = create(:collected_pen, user:, brand: "Pilot", model: "Custom 74")
      sparker = create(:collected_pen, user:, brand: "Sparkery", model: "One")

      exclude = ->(pen, mention) do
        satisfies?(pen, "pen.exclude_mentions", "pen" => { "exclude_mentions" => [mention] })
      end

      expect(exclude.call(parker, "Parker")).to be(false)
      expect(exclude.call(parker, "parkr")).to be(false)
      expect(exclude.call(custom, "pilot custom")).to be(false)
      expect(exclude.call(custom, "Custom74")).to be(false)
      expect(exclude.call(custom, "Parker")).to be(true)
      expect(exclude.call(sparker, "Parker")).to be(true)
      expect(exclude.call(parker, "5")).to be(true)
    end

    it "excludes pens whose comment contains a text, ignoring case" do
      pen = create(:collected_pen, user:, comment: "Grail pen, keep for Sundays")

      expect(
        satisfies?(pen, "pen.comment_exclude", "pen" => { "comment_exclude" => ["grail"] })
      ).to(be(false))
      expect(
        satisfies?(pen, "pen.comment_exclude", "pen" => { "comment_exclude" => ["daily"] })
      ).to(be(true))
    end

    it "matches nib characters for include and exclude" do
      stub = create(:collected_pen, user:, nib: "1.1 stub")
      fine = create(:collected_pen, user:, nib: "F")

      include_stub = { "pen" => { "nib_characters_include" => ["stub"] } }
      exclude_stub = { "pen" => { "nib_characters_exclude" => ["stub"] } }
      expect(satisfies?(stub, "pen.nib_characters_include", include_stub)).to be(true)
      expect(satisfies?(fine, "pen.nib_characters_include", include_stub)).to be(false)
      expect(satisfies?(stub, "pen.nib_characters_exclude", exclude_stub)).to be(false)
      expect(satisfies?(fine, "pen.nib_characters_exclude", exclude_stub)).to be(true)
    end

    it "widens the width classes by the slack" do
      medium = create(:collected_pen, user:, brand: "Pelikan", nib: "M")
      fine = create(:collected_pen, user:, brand: "Lamy", nib: "F")
      fine_constraints = constraints("pen" => { "nib_width" => "fine" })
      broadish_constraints = constraints("pen" => { "nib_width" => "broadish" })

      expect(check.satisfies?(loaded(medium), "pen.nib_width", fine_constraints)).to be(false)
      expect(
        check.satisfies?(
          loaded(medium),
          "pen.nib_width",
          fine_constraints.with("pen.nib_width", "fine", nib_width_slack: 1)
        )
      ).to be(true)
      expect(check.satisfies?(loaded(fine), "pen.nib_width", broadish_constraints)).to be(false)
      expect(
        check.satisfies?(
          loaded(fine),
          "pen.nib_width",
          broadish_constraints.with("pen.nib_width", "broadish", nib_width_slack: 1)
        )
      ).to be(true)
    end

    it "tells used from never-used pens" do
      used = create(:collected_pen, user:)
      unused = create(:collected_pen, user:)
      ink_it(used, create(:collected_ink, user:))

      never = { "pen" => { "usage" => "never_used" } }
      before = { "pen" => { "usage" => "used_before" } }
      expect(satisfies?(unused, "pen.usage", never)).to be(true)
      expect(satisfies?(used, "pen.usage", never)).to be(false)
      expect(satisfies?(used, "pen.usage", before)).to be(true)
      expect(satisfies?(unused, "pen.usage", before)).to be(false)
    end
  end

  describe "ink constraints" do
    it "excludes mentions by brand, line and ink name" do
      kon_peki =
        create(
          :collected_ink,
          user:,
          brand_name: "Pilot",
          line_name: "Iroshizuku",
          ink_name: "Kon-peki"
        )

      exclude = ->(mention) do
        satisfies?(kon_peki, "ink.exclude_mentions", "ink" => { "exclude_mentions" => [mention] })
      end

      expect(exclude.call("Iroshizuku")).to be(false)
      expect(exclude.call("konpeki")).to be(false)
      expect(exclude.call("Kon peki")).to be(false)
      expect(exclude.call("Diamine")).to be(true)
    end

    it "excludes the user's own tags, ignoring case" do
      ink = create(:collected_ink, user:, tags_as_string: "Daily, office")

      tags = ->(tag) { satisfies?(ink, "ink.tags_exclude", "ink" => { "tags_exclude" => [tag] }) }

      expect(tags.call("daily")).to be(false)
      expect(tags.call("weekend")).to be(true)
    end

    it "matches kinds, treating an ink without a kind as no kind at all" do
      sample = create(:collected_ink, user:, kind: "sample")
      no_kind = create(:collected_ink, user:, kind: "")

      samples = { "ink" => { "kinds_include" => ["sample"] } }
      no_samples = { "ink" => { "kinds_exclude" => ["sample"] } }
      expect(satisfies?(sample, "ink.kinds_include", samples)).to be(true)
      expect(satisfies?(no_kind, "ink.kinds_include", samples)).to be(false)
      expect(satisfies?(sample, "ink.kinds_exclude", no_samples)).to be(false)
      expect(satisfies?(no_kind, "ink.kinds_exclude", no_samples)).to be(true)
    end

    it "matches colours leniently and keeps an unknown colour out of includes only" do
      blue = create(:collected_ink, user:, color: "#1f3fbf")
      teal = create(:collected_ink, user:, color: "#008080")
      unknown = create(:collected_ink, user:, color: "")

      include_blue = { "ink" => { "colour_include" => ["blue"] } }
      exclude_blue = { "ink" => { "colour_exclude" => ["blue"] } }
      expect(satisfies?(blue, "ink.colour_include", include_blue)).to be(true)
      expect(satisfies?(teal, "ink.colour_include", include_blue)).to be(true)
      expect(satisfies?(unknown, "ink.colour_include", include_blue)).to be(false)
      expect(satisfies?(blue, "ink.colour_exclude", exclude_blue)).to be(false)
      expect(satisfies?(teal, "ink.colour_exclude", exclude_blue)).to be(false)
      expect(satisfies?(unknown, "ink.colour_exclude", exclude_blue)).to be(true)
    end

    it "reads shimmer and scented from the ink's properties" do
      shimmer = create(:collected_ink, user:, tags_as_string: "shimmer")
      scented = create(:collected_ink, user:, line_name: "Scented")
      plain = create(:collected_ink, user:)

      expect(satisfies?(shimmer, "ink.shimmer", "ink" => { "shimmer" => "include" })).to be(true)
      expect(satisfies?(plain, "ink.shimmer", "ink" => { "shimmer" => "include" })).to be(false)
      expect(satisfies?(shimmer, "ink.shimmer", "ink" => { "shimmer" => "exclude" })).to be(false)
      expect(satisfies?(scented, "ink.scented", "ink" => { "scented" => "exclude" })).to be(false)
      expect(satisfies?(plain, "ink.scented", "ink" => { "scented" => "exclude" })).to be(true)
      expect(check.scented?(loaded(scented))).to be(true)
    end
  end

  describe "pairs" do
    it "checks new and repeat pairings against the pair history" do
      pen = create(:collected_pen, user:)
      tried = create(:collected_ink, user:)
      untried = create(:collected_ink, user:)
      ink_it(pen, tried)

      new_pair = constraints("pair_usage" => "new")
      repeat = constraints("pair_usage" => "repeat")
      expect(check.pair_satisfies?(loaded(pen), loaded(untried), new_pair)).to be(true)
      expect(check.pair_satisfies?(loaded(pen), loaded(tried), new_pair)).to be(false)
      expect(check.pair_satisfies?(loaded(pen), loaded(tried), repeat)).to be(true)
      expect(check.pair_satisfies?(loaded(pen), loaded(untried), repeat)).to be(false)
      expect(check.pair_satisfies?(loaded(pen), loaded(tried), constraints({}))).to be(true)
    end
  end

  describe "#violation_for" do
    let(:pen) { create(:collected_pen, user:, brand: "Pelikan", model: "M800", nib: "B") }
    let(:ink) { create(:collected_ink, user:, brand_name: "Diamine", ink_name: "Oxblood") }

    def violation(hash)
      check.violation_for(pen: loaded(pen), ink: loaded(ink), constraints: constraints(hash))
    end

    it "is nil when the pair meets every constraint" do
      expect(
        violation("pen" => { "nib_width" => "broad" }, "ink" => { "colour_exclude" => [] })
      ).to(be_nil)
    end

    it "names the first pen or ink requirement that fails" do
      expect(violation("pen" => { "nib_width" => "fine" })).to eq(
        "Pelikan M800 does not meet the user's requirement pen.nib_width; " \
          "choose another pen from PENS."
      )
      expect(violation("ink" => { "exclude_mentions" => ["Diamine"] })).to eq(
        "Diamine Oxblood does not meet the user's requirement ink.exclude_mentions; " \
          "choose another ink from INKS."
      )
    end

    it "explains a pairing that breaks pair_usage" do
      expect(violation("pair_usage" => "repeat")).to include("never inked together")
    end

    it "explains a repeated pairing when a new one was asked for" do
      ink_it(pen, ink)

      expect(violation("pair_usage" => "new")).to include("inked together before")
    end
  end

  it "treats a pen without a width as an unknown nib" do
    gold = create(:collected_pen, user:, nib: "14k")
    fude = create(:collected_pen, user:, nib: "Fude")

    expect(check.unknown_nib?(loaded(gold))).to be(true)
    expect(check.unknown_nib?(loaded(fude))).to be(false)
  end
end
