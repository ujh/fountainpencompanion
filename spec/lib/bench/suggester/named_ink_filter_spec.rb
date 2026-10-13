require_relative "bench_helper"

RSpec.describe Bench::Suggester::NamedInkFilter do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let!(:pen) do
    create(:collected_pen, user:, brand: "Lamy", model: "Safari", created_at: as_of - 1.year)
  end
  let!(:harbour) do
    create(
      :collected_ink,
      user:,
      brand_name: "Inkwell",
      ink_name: "Harbour Fog",
      created_at: as_of - 1.year
    )
  end
  let!(:quill) do
    create(
      :collected_ink,
      user:,
      brand_name: "Fernway",
      ink_name: "Quillmoss",
      created_at: as_of - 1.year
    )
  end

  def snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:)

  def ink_ids(instruction) = described_class.new.ink_ids(snapshot, instruction)

  def run(instruction, owner: user, created_at: as_of)
    Bench::Suggester::LoggedRun.new(
      suggester_log(user: owner, created_at:, pen_ids: [pen.id], instruction:)
    )
  end

  describe "#ink_ids" do
    it "finds an ink the request wants" do
      expect(ink_ids("Inkwell Harbour Fog in any pen")).to eq([harbour.id])
    end

    it "finds an ink the request rules out" do
      expect(ink_ids("anything but not Inkwell Harbour Fog")).to eq([harbour.id])
      expect(ink_ids("no harbour fog")).to eq([harbour.id])
    end

    it "finds an ink the request only compares against" do
      expect(ink_ids("something similar to Inkwell Harbour Fog")).to eq([harbour.id])
    end

    it "finds a one-word name right after a negation in a longer request" do
      expect(ink_ids("a fine nib please, no quillmoss")).to eq([quill.id])
    end

    it "lists every ink the request names" do
      expect(ink_ids("Inkwell Harbour Fog or Fernway Quillmoss")).to contain_exactly(
        harbour.id,
        quill.id
      )
    end

    it "finds no ink in a request that names only a pen or a colour" do
      expect(ink_ids("an ink for the Lamy Safari")).to be_empty
      expect(ink_ids("something blue")).to be_empty
    end

    it "ignores a ruled-out colour that is also the name of one of the user's inks" do
      create(
        :collected_ink,
        user:,
        brand_name: "Inkwell",
        ink_name: "Blue",
        created_at: as_of - 1.year
      )

      expect(ink_ids("unused pens, no blue ink")).to be_empty
    end

    it "ignores a one-word name that no negation comes before in a longer request" do
      expect(ink_ids("a fine nib please and quillmoss")).to be_empty
    end

    it "ignores an ink the user did not own at the time" do
      later =
        create(
          :collected_ink,
          user:,
          brand_name: "Inkwell",
          ink_name: "Ember Tide",
          created_at: as_of + 1.day
        )

      expect(ink_ids("Inkwell Ember Tide")).not_to include(later.id)
    end

    it "reads only as much of the request as the widget accepts" do
      padding = "x " * WidgetsController::MAX_EXTRA_USER_INPUT_LENGTH

      expect(ink_ids("#{padding}Inkwell Harbour Fog")).to be_empty
    end
  end

  describe "#call" do
    it "keeps a run that names one of the user's inks" do
      expect(described_class.new.call(run("Use Inkwell Harbour Fog"))).to be(true)
    end

    it "drops a run that names none" do
      expect(described_class.new.call(run("something blue"))).to be(false)
    end

    it "drops a run whose user was deleted" do
      deleted = run("Use Inkwell Harbour Fog")
      deleted.agent_log.update!(owner_id: 0)

      expect(described_class.new.call(deleted)).to be(false)
    end
  end
end
