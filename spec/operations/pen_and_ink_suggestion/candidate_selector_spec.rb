require "rails_helper"

RSpec.describe PenAndInkSuggestion::CandidateSelector do
  let(:user) { create(:user) }
  let(:today) { Date.current }

  def ink_it(pen, ink, inked_on:, archived_on: nil)
    create(:currently_inked, user:, collected_pen: pen, collected_ink: ink, inked_on:, archived_on:)
  end

  def select(
    rejected_pairs: [],
    tier: :free,
    seed: 1,
    resolution: nil,
    fallback: false,
    constraints: {}
  )
    snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user)
    resolution ||= PenAndInkSuggestion::NameResolver::Resolution.empty
    described_class.new(
      snapshot:,
      rejected_pairs:,
      tier:,
      seed:,
      resolution:,
      fallback:,
      constraints: PenAndInkSuggestion::Constraints.from_h(constraints)
    ).call
  end

  def resolution(pen_pins: [], ink_pins: [], pen_brand_filter: nil, ink_brand_filter: nil)
    PenAndInkSuggestion::NameResolver::Resolution.new(
      pen_pins:,
      ink_pins:,
      pen_brand_filter:,
      ink_brand_filter:,
      notes: []
    )
  end

  def small_slices(pens: 5, inks: 5, currently_inked: 15, full_descriptions: 2)
    stub_const(
      "#{described_class}::SLICES",
      { free: { pens:, inks:, currently_inked:, full_descriptions: } }
    )
  end

  describe "candidates" do
    it "sends only uninked fountain pens, keeping pens without a nib" do
      fountain = create(:collected_pen, user:, nib: "F")
      no_nib = create(:collected_pen, user:, nib: "")
      create(:collected_pen, user:, brand: "uni-ball", model: "Signo", nib: "0.38")
      create(:collected_pen, user:, nib: "Rollerball")
      create(:collected_pen, user:, nib: "Glass dip")
      inked = create(:collected_pen, user:, nib: "M")
      create(:collected_pen, user:, nib: "B", archived_on: today)
      create(:collected_pen, nib: "B")
      ink = create(:collected_ink, user:)
      ink_it(inked, ink, inked_on: today - 3)

      selection = select

      expect(selection.pens).to contain_exactly(fountain, no_nib)
      expect(selection.pen_total).to eq(2)
    end

    it "never sends swabs" do
      create(:collected_pen, user:)
      bottle = create(:collected_ink, user:, kind: "bottle")
      no_kind = create(:collected_ink, user:, kind: "")
      create(:collected_ink, user:, kind: "swab")

      expect(select.inks).to contain_exactly(bottle, no_kind)
    end

    it "keeps an ink that is in a pen right now" do
      create(:collected_pen, user:)
      ink = create(:collected_ink, user:)
      ink_it(create(:collected_pen, user:), ink, inked_on: today - 2)

      expect(select.inks).to eq([ink])
    end

    it "drops a cartridge ink when no shown pen takes cartridges" do
      create(:collected_pen, user:, filling_system: "piston")
      bottle = create(:collected_ink, user:, kind: "bottle")
      create(:collected_ink, user:, kind: "cartridge")

      expect(select.inks).to eq([bottle])
    end

    it "drops a cartridge ink when its only fitting pen falls outside the shown slice" do
      small_slices(pens: 1)
      create(:collected_pen, user:, filling_system: "piston")
      cartridge_pen = create(:collected_pen, user:, filling_system: "C/C")
      bottle = create(:collected_ink, user:, kind: "bottle")
      cartridge = create(:collected_ink, user:, kind: "cartridge")
      ink_it(cartridge_pen, cartridge, inked_on: today - 10, archived_on: today - 5)

      selection = select

      expect(selection.pens).not_to include(cartridge_pen)
      expect(selection.inks).to eq([bottle])
    end

    it "fills the ink slice only with inks a shown pen takes" do
      small_slices(pens: 1, inks: 1)
      piston = create(:collected_pen, user:, filling_system: "piston")
      cartridge_pen = create(:collected_pen, user:, filling_system: "C/C")
      bottle = create(:collected_ink, user:, kind: "bottle")
      create(:collected_ink, user:, kind: "cartridge")
      ink_it(cartridge_pen, bottle, inked_on: today - 10, archived_on: today - 5)

      selection = select

      expect(selection.pens).to eq([piston])
      expect(selection.inks).to eq([bottle])
      expect(selection.end_reason).to be_nil
    end

    it "keeps a cartridge ink when a shown pen has a converter or no filling system" do
      create(:collected_pen, user:, filling_system: "piston")
      create(:collected_pen, user:, filling_system: "")
      cartridge = create(:collected_ink, user:, kind: "cartridge")

      expect(select.inks).to eq([cartridge])
    end
  end

  describe "slice sizes" do
    it "sends the whole set when it fits" do
      pens = create_list(:collected_pen, 3, user:)
      inks = create_list(:collected_ink, 4, user:)

      selection = select

      expect(selection.pens).to match_array(pens)
      expect(selection.inks).to match_array(inks)
    end

    it "uses 25 pens and 40 inks for free users, 40 and 80 for patrons, 60 and 120 for admins" do
      create_list(:collected_pen, 61, user:)
      create_list(:collected_ink, 121, user:)

      sizes =
        %i[free premium admin].to_h do |tier|
          selection = select(tier:)
          [
            tier,
            [selection.pens.size, selection.inks.size, selection.pen_total, selection.ink_total]
          ]
        end

      expect(sizes).to eq(
        free: [25, 40, 61, 121],
        premium: [40, 80, 61, 121],
        admin: [60, 120, 61, 121]
      )
    end
  end

  describe "ordering" do
    before { small_slices }

    it "fills 80% of a side with the least recently used items" do
      ink = create(:collected_ink, user:)
      never_used = create_list(:collected_pen, 4, user:)
      used =
        create_list(:collected_pen, 6, user:).each do |pen|
          ink_it(pen, ink, inked_on: today - 10, archived_on: today - 5)
        end

      selection = select

      expect(selection.pens & never_used).to match_array(never_used)
      expect((selection.pens & used).size).to eq(1)
    end

    it "fills the remaining 20% with the most inked items" do
      ink = create(:collected_ink, user:)
      create_list(:collected_pen, 8, user:)
      favourite = create(:collected_pen, user:)
      3.times { |i| ink_it(favourite, ink, inked_on: today - 30 + i, archived_on: today - 20 + i) }
      once = create(:collected_pen, user:)
      ink_it(once, ink, inked_on: today - 30, archived_on: today - 20)

      selection = select

      expect(selection.pens).to include(favourite)
      expect(selection.pens).not_to include(once)
    end

    it "puts inks that are in a pen behind the others" do
      create(:collected_pen, user:)
      free_inks = create_list(:collected_ink, 4, user:)
      inked_inks =
        create_list(:collected_ink, 4, user:).each do |ink|
          ink_it(create(:collected_pen, user:), ink, inked_on: today - 400)
        end

      selection = select

      expect(selection.inks & free_inks).to match_array(free_inks)
      expect((selection.inks & inked_inks).size).to eq(1)
    end

    it "gives the full description to the top-ranked inks" do
      create(:collected_pen, user:)
      top = create_list(:collected_ink, 2, user:)
      other = create(:collected_pen, user:)
      used =
        create_list(:collected_ink, 6, user:).each do |ink|
          ink_it(other, ink, inked_on: today - 10, archived_on: today - 5)
        end

      selection = select

      expect(selection.full_description_inks).to match_array(top)
      expect(used.count { |ink| selection.full_description?(ink) }).to eq(0)
    end

    it "is the same for the same seed and differs for another seed" do
      small_slices(pens: 4, inks: 4)
      create_list(:collected_pen, 20, user:)
      create_list(:collected_ink, 20, user:)

      first = select(seed: 7)
      again = select(seed: 7)
      other = select(seed: 8)

      expect(again.pens).to eq(first.pens)
      expect(again.inks).to eq(first.inks)
      expect([other.pens, other.inks]).not_to eq([first.pens, first.inks])
    end

    it "shows the rows in an order that does not follow the ranking" do
      small_slices(pens: 5, inks: 5, full_descriptions: 5)
      ranked =
        [1000, 800, 600, 400, 200].map do |days|
          pen = create(:collected_pen, user:)
          ink = create(:collected_ink, user:)
          ink_it(pen, ink, inked_on: today - days, archived_on: today - days)
          [pen, ink]
        end
      ranked_pens, ranked_inks = ranked.transpose

      selections = (1..10).map { |seed| select(seed:) }

      expect(selections.map(&:full_description_inks).uniq).to eq([ranked_inks])
      expect(selections.map { |selection| selection.pens.sort_by(&:id) }.uniq).to eq([ranked_pens])
      expect(selections.map(&:pens)).to include(satisfy { |pens| pens != ranked_pens })
      expect(selections.map(&:inks)).to include(satisfy { |inks| inks != ranked_inks })
    end

    it "jitters the order of recently used items so a retry can see other rows" do
      small_slices(pens: 1, inks: 5)
      create(:collected_ink, user:)
      ink = create(:collected_ink, user:)
      pens = create_list(:collected_pen, 10, user:)
      pens.each_with_index do |pen, i|
        ink_it(pen, ink, inked_on: today - 100 - i, archived_on: today - 90 - i)
      end

      first_pens = (1..20).map { |seed| select(seed:).pens.sole }.uniq

      expect(first_pens.size).to be > 1
    end
  end

  describe "currently inked rows" do
    it "lists the newest inkings first, capped per tier" do
      small_slices(currently_inked: 2)
      create(:collected_pen, user:)
      ink = create(:collected_ink, user:)
      oldest, middle, newest =
        [30, 20, 10].map do |days|
          ink_it(create(:collected_pen, user:), ink, inked_on: today - days)
        end

      expect(select.currently_inked).to eq([newest, middle])
      expect(select.currently_inked).not_to include(oldest)
    end

    it "shows 15 rows for free users and 40 for patrons" do
      expect(described_class::SLICES.transform_values { |slice| slice[:currently_inked] }).to eq(
        free: 15,
        premium: 40,
        admin: 40
      )
    end
  end

  describe "ends without a pick" do
    it "ends when no shown ink can go into a shown pen" do
      create(:collected_pen, user:, filling_system: "piston")
      create(:collected_ink, user:, kind: "cartridge")

      selection = select

      expect(selection.end_reason).to eq(:no_compatible_pairs)
      expect(selection).to be_ended
    end

    it "goes on with only cartridges when the one cartridge pen ranks outside the pen slice" do
      small_slices(pens: 1)
      create(:collected_pen, user:, filling_system: "piston")
      cartridge_pen = create(:collected_pen, user:, filling_system: "C/C")
      cartridges = create_list(:collected_ink, 2, user:, kind: "cartridge")
      ink_it(cartridge_pen, cartridges.first, inked_on: today - 10, archived_on: today - 5)

      selection = select

      expect(selection.pens).to eq([cartridge_pen])
      expect(selection.pen_total).to eq(1)
      expect(selection.inks).to match_array(cartridges)
      expect(selection).not_to be_ended
    end

    it "ends when the user rejected every shown pairing" do
      pen = create(:collected_pen, user:)
      inks = create_list(:collected_ink, 2, user:)
      rejected_pairs = inks.map { |ink| { "pen_id" => pen.id, "ink_id" => ink.id } }

      expect(select(rejected_pairs:).end_reason).to eq(:all_pairs_rejected)
    end

    it "goes on while one shown pairing is left, with symbol or string keys" do
      pen = create(:collected_pen, user:)
      first, second = create_list(:collected_ink, 2, user:)

      selection = select(rejected_pairs: [{ pen_id: pen.id, ink_id: first.id }])

      expect(selection).not_to be_ended
      expect(selection.inks).to contain_exactly(first, second)
    end
  end

  describe "pins" do
    it "sends only the pinned pens and marks them, keeping the other side unpinned" do
      pinned = create(:collected_pen, user:)
      create_list(:collected_pen, 3, user:)
      inks = create_list(:collected_ink, 3, user:)

      selection = select(resolution: resolution(pen_pins: [pinned]))

      expect(selection.pens).to eq([pinned])
      expect(selection.pinned_pens).to eq([pinned])
      expect(selection.pinned_inks).to be_empty
      expect(selection.inks).to match_array(inks)
      expect(selection.pen_total).to eq(1)
    end

    it "sends a pinned pen that is currently inked" do
      pinned = create(:collected_pen, user:)
      ink = create(:collected_ink, user:)
      ink_it(pinned, ink, inked_on: today - 3)

      selection = select(resolution: resolution(pen_pins: [pinned]))

      expect(selection.pens).to eq([pinned])
      expect(selection).not_to be_ended
    end

    it "sends only the pinned inks and gives them the full description" do
      create(:collected_pen, user:)
      pinned = create(:collected_ink, user:)
      create_list(:collected_ink, 3, user:)

      selection = select(resolution: resolution(ink_pins: [pinned]))

      expect(selection.inks).to eq([pinned])
      expect(selection.pinned_inks).to eq([pinned])
      expect(selection.full_description?(pinned)).to be(true)
    end

    it "shows only pens that take a pinned cartridge ink" do
      small_slices(pens: 1)
      create_list(:collected_pen, 3, user:, filling_system: "piston")
      cartridge_pen = create(:collected_pen, user:, filling_system: "C/C")
      cartridge = create(:collected_ink, user:, kind: "cartridge")

      selection = select(resolution: resolution(ink_pins: [cartridge]))

      expect(selection.pens).to eq([cartridge_pen])
      expect(selection.inks).to eq([cartridge])
    end

    it "ends when a pinned pen takes none of the pinned inks" do
      pinned_pen = create(:collected_pen, user:, filling_system: "piston")
      cartridge = create(:collected_ink, user:, kind: "cartridge")

      selection = select(resolution: resolution(pen_pins: [pinned_pen], ink_pins: [cartridge]))

      expect(selection.end_reason).to eq(:no_compatible_pairs)
    end

    it "drops a pinned cartridge ink no shown pen takes, with a note, and keeps the others" do
      pinned_pen = create(:collected_pen, user:, filling_system: "piston")
      other_pen = create(:collected_pen, user:, filling_system: "C/C")
      bottle = create(:collected_ink, user:, kind: "bottle")
      cartridge =
        create(:collected_ink, user:, brand_name: "Pilot", ink_name: "Blue", kind: "cartridge")
      ink_it(other_pen, cartridge, inked_on: today - 40, archived_on: today - 30)

      selection =
        select(resolution: resolution(pen_pins: [pinned_pen], ink_pins: [bottle, cartridge]))

      expect(selection.inks).to eq([bottle])
      expect(selection.pinned_inks).to eq([bottle])
      expect(selection.full_description?(cartridge)).to be(false)
      expect(selection.notes).to eq(
        [format(described_class::PINNED_CARTRIDGE_DROPPED_NOTE, name: cartridge.short_name)]
      )
      expect(selection).not_to be_ended
      prompt =
        PenAndInkSuggestion::PickPrompt.new(
          snapshot: PenAndInkSuggestion::CollectionSnapshot.new(user),
          selection:,
          rejected_pairs: [],
          notes: [],
          instruction: "my piston pen with the bottle or the cartridges"
        )
      expect(prompt.user_message).not_to include(cartridge.short_name)
    end

    it "notes a dropped pinned cartridge ink when the run ends" do
      pinned_pen = create(:collected_pen, user:, filling_system: "piston")
      cartridge = create(:collected_ink, user:, kind: "cartridge")

      selection = select(resolution: resolution(pen_pins: [pinned_pen], ink_pins: [cartridge]))

      expect(selection.pinned_inks).to be_empty
      expect(selection.notes).to eq(
        [format(described_class::PINNED_CARTRIDGE_DROPPED_NOTE, name: cartridge.short_name)]
      )
    end

    it "ends when every pairing of the pins was rejected" do
      pinned_pen = create(:collected_pen, user:)
      pinned_ink = create(:collected_ink, user:)
      create(:collected_ink, user:)
      rejected_pairs = [{ "pen_id" => pinned_pen.id, "ink_id" => pinned_ink.id }]

      selection =
        select(
          rejected_pairs:,
          resolution: resolution(pen_pins: [pinned_pen], ink_pins: [pinned_ink])
        )

      expect(selection.end_reason).to eq(:all_pairs_rejected)
    end

    it "moves inks never paired with a pinned pen ahead of those that were" do
      small_slices(inks: 2)
      pinned = create(:collected_pen, user:)
      other_pen = create(:collected_pen, user:)
      tried =
        create_list(:collected_ink, 3, user:).each do |ink|
          ink_it(pinned, ink, inked_on: today - 400, archived_on: today - 390)
        end
      untried =
        create_list(:collected_ink, 2, user:).each do |ink|
          ink_it(other_pen, ink, inked_on: today - 10, archived_on: today - 5)
        end

      selection = select(resolution: resolution(pen_pins: [pinned]))

      expect(selection.inks).to match_array(untried)
      expect(selection.inks & tried).to be_empty
    end
  end

  describe "brand filters" do
    it "keeps only the items of the named brand" do
      pilots = create_list(:collected_pen, 2, user:, brand: "Pilot")
      create(:collected_pen, user:, brand: "Lamy")
      create(:collected_ink, user:)

      selection = select(resolution: resolution(pen_brand_filter: pilots))

      expect(selection.pens).to match_array(pilots)
      expect(selection.pinned_pens).to be_empty
      expect(selection.notes).to be_empty
    end

    it "drops a filter that leaves nothing, with a note" do
      inked_pilot = create(:collected_pen, user:, brand: "Pilot")
      lamy = create(:collected_pen, user:, brand: "Lamy")
      ink = create(:collected_ink, user:)
      ink_it(inked_pilot, ink, inked_on: today - 2)

      selection = select(resolution: resolution(pen_brand_filter: [inked_pilot]))

      expect(selection.pens).to eq([lamy])
      expect(selection.notes).to eq([described_class::BRAND_FILTER_DROPPED_NOTES.fetch(:pen)])
    end
  end

  describe "the fallback path for instruction runs" do
    it "sends 50 pens and 50 inks to free users, 100 to patrons and 200 to admins, unfiltered" do
      create_list(:collected_pen, 201, user:)
      create_list(:collected_ink, 201, user:)

      sizes =
        %i[free premium admin].to_h do |tier|
          selection = select(tier:, fallback: true)
          expect(selection).to be_unfiltered
          [tier, [selection.pens.size, selection.inks.size]]
        end

      expect(sizes).to eq(free: [50, 50], premium: [100, 100], admin: [200, 200])
    end

    it "is not unfiltered on the default path" do
      create(:collected_pen, user:)
      create(:collected_ink, user:)

      expect(select).not_to be_unfiltered
    end
  end
end
