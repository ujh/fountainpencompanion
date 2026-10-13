require_relative "../bench_helper"

RSpec.describe Bench::Suggester::Checks::Constraints do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let(:snapshot) { PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:) }
  let(:pen) do
    create(
      :collected_pen,
      user:,
      created_at: as_of - 1.year,
      brand: "Pilot",
      model: "Custom 74",
      nib: "M"
    )
  end
  let(:ink) do
    create(
      :collected_ink,
      user:,
      created_at: as_of - 1.year,
      brand_name: "Sailor",
      line_name: "Manyo",
      ink_name: "Haha",
      kind: "bottle",
      color: "#2E7D32"
    )
  end

  def statuses(constraints, extra_data = {})
    extra_data = { "pen" => pen.id, "ink" => ink.id }.merge(extra_data)
    normalised = Bench::Suggester::ConstraintSchema.normalise(constraints)
    described_class.new(snapshot:, extra_data:, constraints: normalised).call
  end

  def hard(constraints, extra_data = {}) = statuses(constraints, extra_data)["hard"]

  it "scores nothing without labelled constraints" do
    expect(statuses({})).to eq("hard" => {}, "soft" => {})
    expect(
      hard({ "pen" => { "nib_width" => "any", "nib_grades_include" => [] }, "pair_usage" => "any" })
    ).to eq({})
  end

  it "reports no_suggestion when the run picked nothing" do
    expect(
      hard({ "ink" => { "kinds_include" => ["sample"] } }, { "pen" => nil, "ink" => nil })
    ).to eq("ink.kinds_include" => "no_suggestion")
  end

  describe "nib constraints, checked with NibProfile" do
    it "matches literal grades against the grade on the pen" do
      expect(hard({ "pen" => { "nib_grades_include" => %w[M B] } })).to eq(
        "pen.nib_grades_include" => "met"
      )
      expect(hard({ "pen" => { "nib_grades_exclude" => ["M"] } })).to eq(
        "pen.nib_grades_exclude" => "violated"
      )
    end

    it "uses the Japanese-sized width class for vague widths" do
      create(:collected_pen, user:, created_at: as_of - 1.day, nib: "B")

      expect(hard({ "pen" => { "nib_width" => "fine" } })).to eq("pen.nib_width" => "met")
      expect(hard({ "pen" => { "nib_width" => "broadish" } })).to eq("pen.nib_width" => "violated")
    end

    it "checks grind characters" do
      pen.update!(nib: "1.1 stub")

      expect(hard({ "pen" => { "nib_characters_include" => ["stub"] } })).to eq(
        "pen.nib_characters_include" => "met"
      )
      expect(hard({ "pen" => { "nib_characters_exclude" => %w[stub italic] } })).to eq(
        "pen.nib_characters_exclude" => "violated"
      )
    end
  end

  describe "ink constraints" do
    it "checks kinds" do
      expect(
        hard({ "ink" => { "kinds_include" => ["bottle"], "kinds_exclude" => ["sample"] } })
      ).to eq("ink.kinds_include" => "met", "ink.kinds_exclude" => "met")
    end

    it "checks colours leniently with ColorProfile, cluster tags included" do
      ink.update!(
        micro_cluster: create(:micro_cluster, macro_cluster: create(:macro_cluster, tags: ["teal"]))
      )

      expect(hard({ "ink" => { "colour_include" => %w[green] } })).to eq(
        "ink.colour_include" => "met"
      )
      expect(hard({ "ink" => { "colour_exclude" => %w[teal] } })).to eq(
        "ink.colour_exclude" => "violated"
      )
    end

    it "checks shimmer and scented with InkProperties" do
      ink.update!(tags_as_string: "shimmer")

      expect(hard({ "ink" => { "shimmer" => "exclude" } })).to eq("ink.shimmer" => "violated")
      expect(hard({ "ink" => { "shimmer" => "include", "scented" => "exclude" } })).to eq(
        "ink.shimmer" => "met",
        "ink.scented" => "met"
      )
    end

    it "scores scented: include as a soft wish only" do
      expect(statuses({ "ink" => { "scented" => "include" } })).to eq(
        "hard" => {
        },
        "soft" => {
          "ink.scented" => "violated"
        }
      )
    end

    it "checks the user's own tags" do
      ink.update!(tags_as_string: "Ordered, work")

      expect(hard({ "ink" => { "tags_exclude" => ["ordered"] } })).to eq(
        "ink.tags_exclude" => "violated"
      )
      expect(hard({ "ink" => { "tags_exclude" => ["order"] } })).to eq("ink.tags_exclude" => "met")
    end
  end

  describe "exclusions" do
    it "matches mentions as whole words on the brand and model or the ink names" do
      expect(hard({ "pen" => { "exclude_mentions" => ["pilot"] } })).to eq(
        "pen.exclude_mentions" => "violated"
      )
      expect(hard({ "pen" => { "exclude_mentions" => ["Pil"] } })).to eq(
        "pen.exclude_mentions" => "met"
      )
      expect(hard({ "ink" => { "exclude_mentions" => ["manyo haha"] } })).to eq(
        "ink.exclude_mentions" => "violated"
      )
    end

    it "checks ids and pen comments" do
      pen.update!(comment: "Anna's pen")

      expect(
        hard(
          {
            "pen" => {
              "exclude_ids" => [pen.id],
              "comment_exclude" => ["anna"]
            },
            "ink" => {
              "exclude_ids" => [0]
            }
          }
        )
      ).to eq(
        "pen.exclude_ids" => "violated",
        "pen.comment_exclude" => "violated",
        "ink.exclude_ids" => "met"
      )
    end

    it "never counts a relaxation note for an exclusion" do
      relaxations = %w[pen.exclude_mentions ink.shimmer ink.colour_exclude]
      ink.update!(tags_as_string: "shimmer")

      expect(
        hard(
          {
            "pen" => {
              "exclude_mentions" => ["Pilot"]
            },
            "ink" => {
              "shimmer" => "exclude",
              "colour_exclude" => ["green"]
            }
          },
          { "relaxations" => relaxations }
        )
      ).to eq(
        "pen.exclude_mentions" => "violated",
        "ink.shimmer" => "violated",
        "ink.colour_exclude" => "violated"
      )
    end
  end

  describe "usage" do
    it "checks usage at the time of the run" do
      other_ink = create(:collected_ink, user:, created_at: as_of - 1.year)
      create(
        :currently_inked,
        user:,
        collected_pen: pen,
        collected_ink: other_ink,
        inked_on: as_of.to_date - 50,
        archived_on: as_of.to_date - 40,
        created_at: as_of - 50.days
      )
      create(
        :currently_inked,
        user:,
        collected_pen: create(:collected_pen, user:),
        collected_ink: ink,
        inked_on: as_of.to_date + 2,
        created_at: as_of + 2.days
      )

      expect(
        hard({ "pen" => { "usage" => "used_before" }, "ink" => { "usage" => "never_used" } })
      ).to eq("pen.usage" => "met", "ink.usage" => "met")
    end
  end

  describe "pair_usage" do
    before do
      create(
        :currently_inked,
        user:,
        collected_pen: pen,
        collected_ink: ink,
        inked_on: as_of.to_date - 50,
        archived_on: as_of.to_date - 40,
        created_at: as_of - 50.days
      )
    end

    it "checks the pair history at the time of the run" do
      expect(hard({ "pair_usage" => "repeat" })).to eq("pair_usage" => "met")
      expect(hard({ "pair_usage" => "new" })).to eq("pair_usage" => "unsatisfiable")
    end

    it "is violated when a new pair was possible" do
      create(:collected_ink, user:, created_at: as_of - 1.day)

      expect(hard({ "pair_usage" => "new" })).to eq("pair_usage" => "violated")
    end
  end

  describe "relaxation" do
    it "accepts a relaxation note for a hard include, as a field name or a hash" do
      create(:collected_ink, user:, created_at: as_of - 1.day, kind: "sample")

      expect(hard({ "ink" => { "kinds_include" => ["sample"] } })).to eq(
        "ink.kinds_include" => "violated"
      )
      expect(
        hard(
          { "ink" => { "kinds_include" => ["sample"] } },
          { "relaxations" => ["ink.kinds_include"] }
        )
      ).to eq("ink.kinds_include" => "relaxed")
      expect(
        hard(
          { "ink" => { "kinds_include" => ["sample"] } },
          { "relaxations" => [{ "field" => "ink.kinds_include", "note" => "No samples left" }] }
        )
      ).to eq("ink.kinds_include" => "relaxed")
    end

    it "calls an unrelaxed include that nothing could satisfy unsatisfiable" do
      expect(
        hard(
          { "ink" => { "kinds_include" => ["sample"] }, "pen" => { "nib_grades_include" => ["B"] } }
        )
      ).to eq("pen.nib_grades_include" => "unsatisfiable", "ink.kinds_include" => "unsatisfiable")
    end

    it "looks for satisfying pens among uninked fountain pens only" do
      create(
        :currently_inked,
        user:,
        collected_pen: pen,
        inked_on: as_of.to_date - 50,
        archived_on: as_of.to_date - 40,
        created_at: as_of - 50.days
      )
      create(:collected_pen, user:, created_at: as_of - 1.day, nib: "Ballpoint")
      inked = create(:collected_pen, user:, created_at: as_of - 1.day, nib: "B")
      create(
        :currently_inked,
        user:,
        collected_pen: inked,
        inked_on: as_of.to_date - 1,
        created_at: as_of - 1.day
      )

      expect(hard({ "pen" => { "usage" => "never_used", "nib_grades_include" => ["B"] } })).to eq(
        "pen.usage" => "unsatisfiable",
        "pen.nib_grades_include" => "unsatisfiable"
      )
    end
  end
end
