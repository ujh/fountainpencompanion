require "rails_helper"

describe UsageRecord do
  subject { described_class.new }

  it "requires used_on" do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:used_on)
  end

  it "requires a currently inked" do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:currently_inked)
  end

  it "does not allow two entries for the same day" do
    existing_entry = create(:usage_record)
    subject.currently_inked = existing_entry.currently_inked
    subject.used_on = existing_entry.used_on
    expect(subject).to_not be_valid
  end

  it "does allow two entries for different days" do
    existing_entry = create(:usage_record)
    subject.currently_inked = existing_entry.currently_inked
    subject.used_on = existing_entry.used_on.tomorrow
    expect(subject).to be_valid
  end

  it "does allow two entries on the same day for different currently inkeds" do
    existing_entry = create(:usage_record)
    subject.currently_inked = create(:currently_inked)
    subject.used_on = existing_entry.used_on
    expect(subject).to be_valid
  end
end
