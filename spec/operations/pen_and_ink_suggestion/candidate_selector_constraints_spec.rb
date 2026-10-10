require "rails_helper"

RSpec.describe PenAndInkSuggestion::CandidateSelector do
  let(:user) { create(:user) }
  let(:today) { Date.current }

  def ink_it(pen, ink, inked_on: today - 20, archived_on: today - 10)
    create(:currently_inked, user:, collected_pen: pen, collected_ink: ink, inked_on:, archived_on:)
  end

  def select(rejected_pairs: [], seed: 1, pen_pins: [], ink_pins: [], **constraints)
    resolution =
      PenAndInkSuggestion::NameResolver::Resolution.new(
        pen_pins:,
        ink_pins:,
        pen_brand_filter: nil,
        ink_brand_filter: nil,
        notes: []
      )
    selector(rejected_pairs:, seed:, resolution:, **constraints).call
  end

  def selector(rejected_pairs: [], seed: 1, resolution: nil, **constraints)
    described_class.new(
      snapshot: PenAndInkSuggestion::CollectionSnapshot.new(user),
      rejected_pairs:,
      seed:,
      resolution: resolution || PenAndInkSuggestion::NameResolver::Resolution.empty,
      constraints: PenAndInkSuggestion::Constraints.from_h(constraints)
    )
  end

  def pen(brand, model, nib, **attributes)
    create(:collected_pen, user:, brand:, model:, nib:, **attributes)
  end

  def small_slices(pens: 5, inks: 5)
    stub_const(
      "#{described_class}::SLICES",
      { free: { pens:, inks:, currently_inked: 15, full_descriptions: 2 } }
    )
  end

  describe "nib filters (SQ14)" do
    let!(:custom_74) { pen("Pilot", "Custom 74", "M") }
    let!(:pelikan_m) { pen("Pelikan", "M800", "M") }
    let!(:lamy_f) { pen("Lamy", "Safari", "F") }
    let!(:lamy_b) { pen("Lamy", "2000", "B") }
    let!(:bare_08) { pen("Kaweco", "Sport", "0.8 mm") }
    let!(:stub_15) { pen("Lamy", "Joy", "1.5 stub") }
    let!(:flex_f) { pen("Noodler's", "Ahab", "F flex") }
    let!(:jinhao_fude) { pen("Jinhao", "X159", "Fude") }
    let!(:gold_only) { pen("TWSBI", "Diamond 580", "14k") }

    before { create(:collected_ink, user:) }

    def pens_for(pen_constraints)
      select(pen: pen_constraints).pens
    end

    it "matches a literal grade on the pen, whatever its width class" do
      expect(pens_for(nib_grades_include: ["M"])).to contain_exactly(custom_74, pelikan_m)
    end

    it "matches either of two grades, a gradeless fude through its nominal width class" do
      expect(pens_for(nib_grades_include: %w[M B])).to contain_exactly(
        custom_74,
        pelikan_m,
        lamy_b,
        bare_08,
        jinhao_fude
      )
    end

    it "drops an excluded grade and keeps pens whose grade is unknown" do
      expect(pens_for(nib_grades_exclude: ["M"])).to contain_exactly(
        lamy_f,
        lamy_b,
        bare_08,
        stub_15,
        flex_f,
        jinhao_fude,
        gold_only
      )
    end

    it "matches a bare 0.8 mm pen to B through the width class, but not a 1.5 mm stub" do
      selection = select(pen: { nib_grades_include: ["B"] })

      expect(selection.pens).to include(bare_08)
      expect(selection.pens).not_to include(stub_15)
    end

    it "reads broad-ish as W4+ or a broad-ish character, so a Pilot M is not broad-ish" do
      expect(pens_for(nib_width: "broadish")).to contain_exactly(
        pelikan_m,
        lamy_b,
        bare_08,
        stub_15,
        jinhao_fude
      )
    end

    it "reads broad as W5+, so a flex F is not broad" do
      expect(pens_for(nib_width: "broad")).to contain_exactly(lamy_b, bare_08, stub_15, jinhao_fude)
    end

    it "reads fine as W1-W3 without broad-ish characters, which leaves out the Fude" do
      expect(pens_for(nib_width: "fine")).to contain_exactly(custom_74, lamy_f, flex_f)
    end

    it "matches nib characters" do
      expect(pens_for(nib_characters_include: ["stub"])).to contain_exactly(stub_15)
      expect(pens_for(nib_characters_exclude: %w[stub fude flex])).not_to include(
        stub_15,
        jinhao_fude,
        flex_f
      )
    end

    it "leaves pens without a recognisable nib out of an include filter and says so" do
      no_nib = pen("Platinum", "Preppy", "")

      selection = select(pen: { nib_width: "broadish" })

      expect(selection.pens).not_to include(gold_only, no_nib)
      expect(selection.notes).to eq(
        ["2 pens without a recognisable nib size were left out of the nib filter."]
      )
    end

    it "counts a single unknown nib in the singular" do
      expect(select(pen: { nib_grades_include: ["F"] }).notes).to eq(
        ["1 pen without a recognisable nib size was left out of the nib filter."]
      )
    end

    it "keeps unknown nibs and adds no note when no nib filter is active" do
      selection = select(pen: { nib_grades_exclude: ["BB"] })

      expect(selection.pens).to include(gold_only)
      expect(selection.notes).to be_empty
    end
  end

  describe "ink filters" do
    let!(:fountain_pen) { create(:collected_pen, user:) }

    it "keeps only the requested kinds and drops excluded kinds" do
      sample = create(:collected_ink, user:, kind: "sample")
      bottle = create(:collected_ink, user:, kind: "bottle")
      no_kind = create(:collected_ink, user:, kind: "")

      expect(select(ink: { kinds_include: ["sample"] }).inks).to eq([sample])
      expect(select(ink: { kinds_exclude: ["sample"] }).inks).to contain_exactly(bottle, no_kind)
    end

    it "matches colours leniently, excluding a blue-ish teal along with the blues" do
      blue = create(:collected_ink, user:, color: "#1f3fbf")
      teal = create(:collected_ink, user:, color: "#008080")
      red = create(:collected_ink, user:, color: "#c0392b")
      unknown = create(:collected_ink, user:, color: "")

      expect(select(ink: { colour_include: ["blue"] }).inks).to contain_exactly(blue, teal)
      expect(select(ink: { colour_exclude: ["blue"] }).inks).to contain_exactly(red, unknown)
    end

    it "filters shimmer both ways and scented out" do
      shimmer = create(:collected_ink, user:, tags_as_string: "shimmer")
      scented = create(:collected_ink, user:, line_name: "Scented")
      plain = create(:collected_ink, user:)

      expect(select(ink: { shimmer: "include" }).inks).to eq([shimmer])
      expect(select(ink: { shimmer: "exclude" }).inks).to contain_exactly(scented, plain)
      expect(select(ink: { scented: "exclude" }).inks).to contain_exactly(shimmer, plain)
    end

    it "only moves scented inks ahead when they are asked for" do
      small_slices(inks: 1)
      create_list(:collected_ink, 3, user:)
      scented = create(:collected_ink, user:, line_name: "Scented")
      ink_it(fountain_pen, scented, inked_on: today - 5, archived_on: today - 2)

      expect(select.inks).not_to include(scented)
      expect(select(ink: { scented: "include" }).inks).to eq([scented])
    end

    it "drops mentions, the user's tags and pen comments" do
      parker = create(:collected_pen, user:, brand: "Parker", model: "51")
      grail = create(:collected_pen, user:, comment: "Grail, Sundays only")
      diamine = create(:collected_ink, user:, brand_name: "Diamine", ink_name: "Oxblood")
      office = create(:collected_ink, user:, tags_as_string: "office")
      other = create(:collected_ink, user:, brand_name: "KWZ", ink_name: "Cherry")

      selection =
        select(
          pen: {
            exclude_mentions: ["Parker"],
            comment_exclude: ["grail"]
          },
          ink: {
            exclude_mentions: ["Diamine"],
            tags_exclude: ["Office"]
          }
        )

      expect(selection.pens).to eq([fountain_pen])
      expect(selection.pens).not_to include(parker, grail)
      expect(selection.inks).to eq([other])
      expect(selection.inks).not_to include(diamine, office)
    end

    it "keeps only never-used or used items" do
      used_ink = create(:collected_ink, user:)
      new_ink = create(:collected_ink, user:)
      ink_it(fountain_pen, used_ink)

      expect(select(ink: { usage: "never_used" }).inks).to eq([new_ink])
      expect(select(ink: { usage: "used_before" }).inks).to eq([used_ink])
    end
  end

  describe "sort" do
    it "replaces the novelty order with the most used items" do
      small_slices(pens: 1)
      ink = create(:collected_ink, user:)
      create_list(:collected_pen, 3, user:)
      favourite = create(:collected_pen, user:)
      3.times { |i| ink_it(favourite, ink, inked_on: today - 30 + i, archived_on: today - 25 + i) }
      once = create(:collected_pen, user:)
      ink_it(once, ink)

      picks = (1..5).map { |seed| select(pen: { sort: "most_used" }, seed:).pens }

      expect(picks.uniq).to eq([[favourite]])
      expect(select.pens).not_to eq([favourite])
    end

    it "takes the least recently used items without jitter" do
      small_slices(inks: 2)
      pen = create(:collected_pen, user:)
      never = create(:collected_ink, user:)
      oldest = create(:collected_ink, user:)
      ink_it(pen, oldest, inked_on: today - 300, archived_on: today - 290)
      [100, 90, 80, 70].each do |days|
        ink_it(
          pen,
          create(:collected_ink, user:),
          inked_on: today - days,
          archived_on: today - days
        )
      end

      picks = (1..5).map { |seed| select(ink: { sort: "least_recent" }, seed:).inks }

      expect(picks.map { |inks| inks.sort_by(&:id) }.uniq).to eq([[never, oldest]])
    end
  end

  describe "hard exclusions" do
    it "are never relaxed, and a relaxable include gives way instead" do
      create(:collected_pen, user:)
      create(:collected_ink, user:, kind: "sample", color: "#1f3fbf")
      red_bottle = create(:collected_ink, user:, kind: "bottle", color: "#c0392b")

      selection = select(ink: { colour_exclude: ["blue"], kinds_include: ["sample"] })

      expect(selection.inks).to eq([red_bottle])
      expect(selection.relaxations).to eq(
        [{ "field" => "ink.kinds_include", "step" => "dropped", "from" => ["sample"] }]
      )
      expect(selection.effective_constraints.value("ink.colour_exclude")).to eq(["blue"])
    end

    it "end the run with a message naming what left the ink side empty" do
      create(:collected_pen, user:)
      create(:collected_ink, user:, color: "#1f3fbf")
      create(:collected_ink, user:, color: "#3050d0", tags_as_string: "shimmer")
      create(:collected_ink, user:, color: "#2040c0", line_name: "Scented")

      selection = select(ink: { colour_exclude: ["blue"], shimmer: "exclude", scented: "any" })

      expect(selection.end_reason).to eq(:excluded_all)
      expect(selection.end_message).to eq(
        "None of your inks is left after excluding blue inks and shimmer inks. " \
          "Change your request and try again."
      )
      expect(selection.pens).to be_empty
      expect(selection.inks).to be_empty
    end

    it "name only the exclusions that removed something" do
      create(:collected_pen, user:)
      create(:collected_ink, user:, brand_name: "Diamine", color: "#1f3fbf")

      selection = select(ink: { colour_exclude: %w[blue red], exclude_mentions: ["KWZ"] })

      expect(selection.end_message).to start_with(
        "None of your inks is left after excluding blue or red inks."
      )
    end

    it "end the run when they leave no pen" do
      create(:collected_pen, user:, brand: "Parker")
      create(:collected_ink, user:)

      selection = select(pen: { exclude_mentions: ["Parker"] })

      expect(selection.end_reason).to eq(:excluded_all)
      expect(selection.end_message).to eq(
        "None of your uninked pens is left after excluding \"Parker\". " \
          "Change your request and try again."
      )
    end
  end

  describe "the fixed relax order" do
    let!(:fountain_pen) { create(:collected_pen, user:) }

    it "relaxes ink usage first" do
      used_red_sample = create(:collected_ink, user:, kind: "sample", color: "#c0392b")
      create(:collected_ink, user:, kind: "bottle", color: "#1f3fbf")
      ink_it(fountain_pen, used_red_sample)

      selection =
        select(ink: { usage: "never_used", kinds_include: ["sample"], colour_include: ["red"] })

      expect(selection.inks).to eq([used_red_sample])
      expect(selection.relaxations.map { |relaxation| relaxation["field"] }).to eq(["ink.usage"])
      expect(selection.notes).to eq(
        [
          "All your inks that fit the rest of your request have been used before, " \
            "so I included those."
        ]
      )
      expect(selection.effective_constraints.value("ink.usage")).to eq("any")
    end

    it "relaxes shimmer before colour" do
      red_sample = create(:collected_ink, user:, kind: "sample", color: "#c0392b")
      create(:collected_ink, user:, kind: "sample", color: "#1f3fbf", tags_as_string: "shimmer")

      selection = select(ink: { shimmer: "include", colour_include: ["red"] })

      expect(selection.inks).to eq([red_sample])
      expect(selection.notes).to eq(
        [
          "None of your inks that fit the rest of your request has shimmer, " \
            "so I included inks without it."
        ]
      )
    end

    it "widens the colour to neighbouring families before dropping it" do
      orange_sample = create(:collected_ink, user:, kind: "sample", color: "#e67e22")
      create(:collected_ink, user:, kind: "sample", color: "#27ae60")

      selection = select(ink: { colour_include: ["red"], kinds_include: ["sample"] })

      expect(selection.inks).to eq([orange_sample])
      expect(selection.relaxations).to eq(
        [
          {
            "field" => "ink.colour_include",
            "step" => "widened",
            "from" => ["red"],
            "to" => %w[red orange pink brown]
          }
        ]
      )
      expect(selection.notes).to eq(
        [
          "None of your inks that fit the rest of your request is red, so I included " \
            "neighbouring colours (orange, pink or brown)."
        ]
      )
    end

    it "drops the colour, then the kind, as a last resort" do
      green_bottle = create(:collected_ink, user:, kind: "bottle", color: "#27ae60")

      selection = select(ink: { colour_include: ["red"], kinds_include: ["sample"] })

      expect(selection.inks).to eq([green_bottle])
      expect(
        selection.relaxations.map { |relaxation| relaxation.values_at("field", "step") }
      ).to eq([%w[ink.colour_include dropped], %w[ink.kinds_include dropped]])
      expect(selection.notes).to eq(
        [
          "None of your inks is red, so I chose from all colours.",
          "You have no ink samples, so I picked from all your inks."
        ]
      )
      expect(selection.effective_constraints.filters?(:ink)).to be(false)
    end

    it "drops the kind alone when no sample is left" do
      bottle = create(:collected_ink, user:, kind: "bottle")

      selection = select(ink: { kinds_include: ["sample"] })

      expect(selection.inks).to eq([bottle])
      expect(selection.notes).to eq(["You have no ink samples, so I picked from all your inks."])
    end

    it "relaxes the kind on cartridge compatibility, never the pairing rule" do
      fountain_pen.update!(filling_system: "piston")
      create(:collected_ink, user:, kind: "cartridge")
      bottle = create(:collected_ink, user:, kind: "bottle")

      selection = select(ink: { kinds_include: ["cartridge"] })

      expect(selection.inks).to eq([bottle])
      expect(selection.notes).to eq(["You have no cartridges, so I picked from all your inks."])
    end

    context "for pens" do
      before { create(:collected_ink, user:) }

      it "relaxes pen usage, then nib characters, before the width" do
        used_stub = pen("Lamy", "Joy", "1.1 stub")
        ink_it(used_stub, create(:collected_ink, user:))
        pen("Pelikan", "M800", "M")

        selection =
          select(
            pen: {
              usage: "never_used",
              nib_characters_include: ["stub"],
              nib_width: "broadish"
            }
          )

        expect(selection.pens).to eq([used_stub])
        expect(selection.relaxations.map { |relaxation| relaxation["field"] }).to eq(["pen.usage"])
      end

      it "drops nib characters before widening the width" do
        fountain_pen.update!(nib: "EF")
        pelikan = pen("Pelikan", "M800", "M")

        selection = select(pen: { nib_characters_include: ["italic"], nib_width: "broad" })

        expect(selection.pens).to eq([pelikan])
        expect(selection.relaxations.map { |relaxation| relaxation.values_at("field", "step") }).to(
          eq([%w[pen.nib_characters_include dropped], %w[pen.nib_width widened]])
        )
      end

      it "widens a width by one class, with a note" do
        fountain_pen.update!(nib: "EF")
        pilot_m = pen("Pilot", "Custom 74", "M")

        selection = select(pen: { nib_width: "broadish" })

        expect(selection.pens).to eq([pilot_m])
        expect(selection.notes).to eq(
          ["None of your uninked pens has a broad-ish nib, so I went one nib size finer."]
        )
        expect(selection.effective_constraints.nib_width_slack).to eq(1)
      end

      it "widens fine towards broader nibs" do
        fountain_pen.update!(nib: "BB")
        pelikan = pen("Pelikan", "M800", "M")

        selection = select(pen: { nib_width: "fine" })

        expect(selection.pens).to eq([pelikan])
        expect(selection.notes).to eq(
          ["None of your uninked pens has a fine nib, so I went one nib size broader."]
        )
      end

      it "widens grades to their neighbours, then drops them" do
        fountain_pen.update!(nib: "M")
        expect(select(pen: { nib_grades_include: ["B"] }).notes).to eq(
          [
            "None of your uninked pens has a B nib, so I included the neighbouring sizes " \
              "(M or BB)."
          ]
        )

        fountain_pen.update!(nib: "EF")
        selection = select(pen: { nib_grades_include: ["B"] })
        expect(selection.pens).to eq([fountain_pen])
        expect(selection.notes).to eq(
          ["None of your uninked pens has a B nib, so I chose from all nib sizes."]
        )
      end
    end
  end

  describe "pair_usage" do
    let!(:pinned_pen) { create(:collected_pen, user:) }
    let!(:other_pen) { create(:collected_pen, user:) }
    let!(:tried) { create(:collected_ink, user:) }
    let!(:untried) { create(:collected_ink, user:) }

    before { ink_it(pinned_pen, tried) }

    it "shows only inks never paired with a pinned pen when a new pairing is wanted" do
      selection = select(pair_usage: "new", pen_pins: [pinned_pen])

      expect(selection.inks).to eq([untried])
      expect(selection.effective_constraints.pair_usage).to eq("new")
    end

    it "relaxes a new pairing with a note when every ink was paired with the pin" do
      ink_it(pinned_pen, untried)

      selection = select(pair_usage: "new", pen_pins: [pinned_pen])

      expect(selection.inks).to contain_exactly(tried, untried)
      expect(selection.notes).to eq(
        ["Every pairing I could show you has been inked before, so I allowed pairings you've used."]
      )
      expect(selection.effective_constraints.pair_usage).to eq("any")
    end

    it "relaxes a new pairing when every shown pair was inked before" do
      ink_it(other_pen, tried)
      untried.destroy!

      selection = select(pair_usage: "new")

      expect(selection.relaxations.map { |relaxation| relaxation["field"] }).to eq(["pair_usage"])
      expect(selection).not_to be_ended
    end

    it "shows only pens and inks from past pairings when a repeat is wanted" do
      selection = select(pair_usage: "repeat")

      expect(selection.pens).to eq([pinned_pen])
      expect(selection.inks).to eq([tried])
    end

    it "shows only inks paired with a pinned pen before when a repeat is wanted" do
      selection = select(pair_usage: "repeat", pen_pins: [other_pen])

      expect(selection.inks).to contain_exactly(tried, untried)
      expect(selection.notes).to eq(
        [
          "None of the pens and inks that fit were inked together before, so I allowed new " \
            "pairings."
        ]
      )
    end

    it "keeps a repeat within the shown pens" do
      small_slices(pens: 1)
      later_ink = create(:collected_ink, user:)
      ink_it(other_pen, later_ink, inked_on: today - 400, archived_on: today - 390)

      selection = select(pair_usage: "repeat")

      expect(selection.pens).to eq([other_pen])
      expect(selection.inks).to eq([later_ink])
    end
  end

  describe "pinned items" do
    it "narrows the pins by the side's constraints" do
      broad = pen("Lamy", "2000", "B")
      fine = pen("Lamy", "2000", "EF")
      create(:collected_ink, user:)

      selection = select(pen: { nib_width: "broad" }, pen_pins: [broad, fine])

      expect(selection.pens).to eq([broad])
      expect(selection.pinned_pens).to eq([broad])
      expect(selection.relaxations).to be_empty
    end

    it "keeps every pin with a note when none meets the side's constraints" do
      fine = pen("Lamy", "2000", "EF")
      parker = pen("Parker", "51", "M")
      create(:collected_ink, user:)

      selection =
        select(pen: { nib_width: "broad", exclude_mentions: ["Lamy"] }, pen_pins: [fine, parker])

      expect(selection.pens).to contain_exactly(fine, parker)
      expect(selection.notes).to eq(
        ["The pens you named don't meet your other pen requirements, so I kept them anyway."]
      )
      expect(
        selection.relaxations.map { |relaxation| relaxation.values_at("field", "step") }
      ).to eq([%w[pen.exclude_mentions pinned], %w[pen.nib_width pinned]])
      expect(selection.effective_constraints.filters?(:pen)).to be(false)
    end

    it "pins the pen of the newest rejected pair when asked to keep it" do
      kept = create(:collected_pen, user:)
      older = create(:collected_pen, user:)
      create(:collected_pen, user:)
      ink = create(:collected_ink, user:)
      rejected_pairs = [
        { "pen_id" => older.id, "ink_id" => ink.id },
        { "pen_id" => kept.id, "ink_id" => ink.id }
      ]
      keeping = selector(keep_from_previous: "pen", rejected_pairs:)

      selection = keeping.call

      expect(selection.pens).to eq([kept])
      expect(selection.pinned_pens).to eq([kept])
      expect(keeping.log_pins).to eq([{ "pen_id" => kept.id }])
    end

    it "pins the ink of the newest rejected pair when asked to keep it" do
      create(:collected_pen, user:)
      kept = create(:collected_ink, user:)
      create(:collected_ink, user:)
      rejected_pairs = [{ pen_id: create(:collected_pen, user:).id, ink_id: kept.id }]

      selection = select(keep_from_previous: "ink", rejected_pairs:)

      expect(selection.pinned_inks).to eq([kept])
    end

    it "pins nothing extra when there is no previous pair to keep" do
      pens = create_list(:collected_pen, 2, user:)
      create(:collected_ink, user:)

      expect(select(keep_from_previous: "pen").pens).to match_array(pens)
    end
  end

  describe "server notes" do
    before do
      create(:collected_pen, user:)
      create(:collected_ink, user:)
    end

    it "notes an out-of-scope request and several requested pairs, then picks as usual" do
      selection = select(out_of_scope: true, requested_count: 5)

      expect(selection.notes).to eq(
        [described_class::OUT_OF_SCOPE_NOTE, described_class::REQUESTED_COUNT_NOTE]
      )
      expect(selection).not_to be_ended
    end
  end

  describe "the re-check of a pick" do
    it "accepts a pick from a relaxed side and rejects one that breaks a kept constraint" do
      fountain_pen = create(:collected_pen, user:)
      bottle = create(:collected_ink, user:, kind: "bottle", color: "#c0392b")
      selection = select(ink: { kinds_include: ["sample"], colour_exclude: ["blue"] })

      expect(selection.violation_for(pen: fountain_pen, ink: bottle)).to be_nil
      expect(selection.effective_constraints.value("ink.colour_exclude")).to eq(["blue"])
      expect(selection).to be_constrained
    end

    it "rejects a shown pair that breaks pair_usage" do
      pinned = create(:collected_pen, user:)
      tried = create(:collected_ink, user:)
      create(:collected_ink, user:)
      ink_it(pinned, tried)
      selection = select(pair_usage: "new", pen_pins: [pinned])
      selection.inks << tried

      expect(selection.violation_for(pen: pinned, ink: tried)).to include("inked together before")
    end
  end

  it "changes nothing with empty constraints" do
    create_list(:collected_pen, 3, user:)
    create_list(:collected_ink, 3, user:)

    selection = select

    expect(selection.relaxations).to be_empty
    expect(selection.notes).to be_empty
    expect(selection.effective_constraints).to eq(PenAndInkSuggestion::Constraints.empty)
    expect(selection).not_to be_constrained
  end
end
