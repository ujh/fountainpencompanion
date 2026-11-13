require "rails_helper"

describe ErrorReport do
  it "is valid with a description" do
    expect(described_class.new(description: "The link is broken")).to be_valid
  end

  it "requires a description" do
    report = described_class.new(description: "   ")

    expect(report).not_to be_valid
    expect(report.errors.full_messages).to eq(["Description can't be blank"])
  end

  it "rejects a description longer than 2000 characters" do
    expect(described_class.new(description: "a" * 2000)).to be_valid
    expect(described_class.new(description: "a" * 2001)).not_to be_valid
  end

  it "treats a description that is not a string as missing" do
    report = described_class.new(description: ["The link is broken"])

    expect(report).not_to be_valid
    expect(report.description).to be_nil
  end
end
