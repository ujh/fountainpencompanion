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
    described_class.new.perform(user.id, row)
    ink = user.collected_inks.first
    expect(ink.brand_name).to eq("Diamine")
    expect(ink.ink_name).to eq("Oxblood")
  end

  it "sets created_at from date_added" do
    described_class.new.perform(user.id, row("date_added" => "2020-01-15"))
    expect(user.collected_inks.first.created_at.to_date).to eq(Date.new(2020, 1, 15))
  end

  it "ignores a malformed date_added" do
    expect {
      described_class.new.perform(user.id, row("date_added" => "not a date"))
    }.not_to raise_error
    expect(user.collected_inks.count).to eq(1)
  end

  it "leaves created_at to the default when date_added is blank" do
    described_class.new.perform(user.id, row("date_added" => ""))
    expect(user.collected_inks.first.created_at).to be_present
  end
end
