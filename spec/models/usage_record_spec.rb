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
    ci = create(:currently_inked, inked_on: 5.days.ago.to_date)
    existing_entry = create(:usage_record, currently_inked: ci, used_on: Date.current)
    subject.currently_inked = existing_entry.currently_inked
    subject.used_on = existing_entry.used_on.yesterday
    expect(subject).to be_valid
  end

  it "does allow two entries on the same day for different currently inkeds" do
    existing_entry = create(:usage_record)
    subject.currently_inked = create(:currently_inked)
    subject.used_on = existing_entry.used_on
    expect(subject).to be_valid
  end

  describe "used_on date range validation" do
    let(:currently_inked) { create(:currently_inked, inked_on: 10.days.ago.to_date) }

    it "allows used_on on the inked_on date" do
      record =
        build(:usage_record, currently_inked: currently_inked, used_on: currently_inked.inked_on)
      expect(record).to be_valid
    end

    it "allows used_on on today" do
      record = build(:usage_record, currently_inked: currently_inked, used_on: Date.current)
      expect(record).to be_valid
    end

    it "does not allow used_on before inked_on" do
      record =
        build(
          :usage_record,
          currently_inked: currently_inked,
          used_on: currently_inked.inked_on - 1.day
        )
      expect(record).to_not be_valid
      expect(record.errors[:used_on]).to include(
        "cannot be before the currently inked entry was inked"
      )
    end

    it "does not allow used_on in the future" do
      record = build(:usage_record, currently_inked: currently_inked, used_on: Date.current + 1.day)
      expect(record).to_not be_valid
      expect(record.errors[:used_on]).to include("cannot be in the future")
    end

    context "with an archived currently_inked" do
      let(:archived_currently_inked) do
        ci = create(:currently_inked, inked_on: 20.days.ago.to_date)
        ci.update!(archived_on: 5.days.ago.to_date)
        ci
      end

      it "allows used_on on the archived_on date" do
        record =
          build(
            :usage_record,
            currently_inked: archived_currently_inked,
            used_on: archived_currently_inked.archived_on
          )
        expect(record).to be_valid
      end

      it "does not allow used_on after archived_on" do
        record =
          build(
            :usage_record,
            currently_inked: archived_currently_inked,
            used_on: archived_currently_inked.archived_on + 1.day
          )
        expect(record).to_not be_valid
        expect(record.errors[:used_on]).to include(
          "cannot be after the currently inked entry was archived"
        )
      end

      it "allows used_on between inked_on and archived_on" do
        record =
          build(
            :usage_record,
            currently_inked: archived_currently_inked,
            used_on: archived_currently_inked.inked_on + 1.day
          )
        expect(record).to be_valid
      end
    end
  end
end
