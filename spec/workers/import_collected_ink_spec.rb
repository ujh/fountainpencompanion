require "rails_helper"

describe ImportCollectedInk do
  let(:user) { create(:user) }

  def row(overrides = {})
    {
      "brand_name" => "Diamine",
      "line_name" => "",
      "ink_name" => "Oxblood",
      "kind" => "bottle"
    }.merge(overrides)
  end

  it "imports an ink" do
    described_class.new.perform(user.id, [row])
    ink = user.collected_inks.first
    expect(ink.brand_name).to eq("Diamine")
    expect(ink.ink_name).to eq("Oxblood")
  end

  it "sets created_at from date_added" do
    described_class.new.perform(user.id, [row("date_added" => "2020-01-15")])
    expect(user.collected_inks.first.created_at.to_date).to eq(Date.new(2020, 1, 15))
  end

  it "ignores a malformed date_added" do
    expect {
      described_class.new.perform(user.id, [row("date_added" => "not a date")])
    }.not_to raise_error
    expect(user.collected_inks.count).to eq(1)
  end

  it "leaves created_at to the default when date_added is blank" do
    described_class.new.perform(user.id, [row("date_added" => "")])
    expect(user.collected_inks.first.created_at).to be_present
  end

  it "re-imports an existing ink with a blank date_added" do
    described_class.new.perform(user.id, [row])
    expect { described_class.new.perform(user.id, [row("date_added" => "")]) }.not_to raise_error
    expect(user.collected_inks.count).to eq(1)
    expect(user.collected_inks.first.created_at).to be_present
  end

  describe "duplicate rows" do
    it "imports a bottle and a sample of the same ink as separate inks" do
      described_class.new.perform(user.id, [row("kind" => "bottle")])
      described_class.new.perform(user.id, [row("kind" => "sample")])
      expect(user.collected_inks.pluck(:kind)).to contain_exactly("bottle", "sample")
      expect(user.collected_inks.pluck(:comment)).to all(be_blank)
    end

    it "imports the same ink and kind twice as separate inks with a comment" do
      described_class.new.perform(user.id, [row("kind" => "sample"), row("kind" => "sample")])
      expect(user.collected_inks.order(:id).pluck(:kind, :comment)).to eq(
        [["sample", ""], ["sample", "Sample no. 2"]]
      )
    end

    it "keeps a comment given in the row" do
      described_class.new.perform(user.id, [row, row("comment" => "Second bottle")])
      expect(user.collected_inks.order(:id).pluck(:comment)).to eq(["", "Second bottle"])
    end

    it "updates the same inks when importing the duplicates again" do
      rows = [row("kind" => "sample"), row("kind" => "sample", "private" => "x")]
      2.times { described_class.new.perform(user.id, rows.map(&:dup)) }
      expect(user.collected_inks.order(:id).pluck(:private, :comment)).to eq(
        [[false, ""], [true, "Sample no. 2"]]
      )
    end

    it "matches existing inks regardless of kind when the row has no kind" do
      existing =
        create(
          :collected_ink,
          user: user,
          brand_name: "Diamine",
          ink_name: "Oxblood",
          kind: "sample"
        )
      described_class.new.perform(user.id, [row("kind" => nil, "private" => "x")])
      expect(user.collected_inks.count).to eq(1)
      expect(existing.reload).to be_private
    end

    it "matches existing inks with surrounding whitespace in the row" do
      2.times { described_class.new.perform(user.id, [row("ink_name" => " Oxblood ")]) }
      expect(user.collected_inks.count).to eq(1)
    end
  end

  describe ".duplicate_key" do
    it "normalizes whitespace and the case of the kind" do
      expect(
        described_class.duplicate_key(row("ink_name" => " Oxblood ", "kind" => " Sample"))
      ).to eq(["Diamine", "", "Oxblood", "sample"])
    end
  end
end
