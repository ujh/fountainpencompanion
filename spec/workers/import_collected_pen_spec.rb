require "rails_helper"

describe ImportCollectedPen do
  let(:user) { create(:user) }

  def row(overrides = {})
    { "brand" => "Wing Sung", "model" => "618", "nib" => "M", "color" => "black" }.merge(overrides)
  end

  it "imports a pen" do
    described_class.new.perform(user.id, row)
    pen = user.collected_pens.first
    expect(pen.brand).to eq("Wing Sung")
    expect(pen.model).to eq("618")
  end

  it "sets created_at from date_added" do
    described_class.new.perform(user.id, row("date_added" => "2020-01-15"))
    expect(user.collected_pens.first.created_at.to_date).to eq(Date.new(2020, 1, 15))
  end

  it "ignores a malformed date_added" do
    expect {
      described_class.new.perform(user.id, row("date_added" => "not a date"))
    }.not_to raise_error
    expect(user.collected_pens.count).to eq(1)
  end

  it "leaves created_at to the default when date_added is blank" do
    described_class.new.perform(user.id, row("date_added" => ""))
    expect(user.collected_pens.first.created_at).to be_present
  end
end
