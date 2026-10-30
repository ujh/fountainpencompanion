require "rails_helper"

describe PlausibleDateValidator do
  include ActiveSupport::Testing::TimeHelpers

  subject { model_class.new }

  let(:model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes

      def self.name = "DatedThing"

      attribute :happened_on, :date
      validates :happened_on, plausible_date: true
    end
  end

  before { travel_to(Date.new(2026, 10, 30)) }

  it "accepts a blank date" do
    expect(subject).to be_valid
  end

  it "accepts the earliest date" do
    subject.happened_on = Date.new(1900, 1, 1)
    expect(subject).to be_valid
  end

  it "rejects a date before 1900" do
    subject.happened_on = Date.new(1899, 12, 31)
    expect(subject).to be_invalid
    expect(subject.errors[:happened_on]).to eq(["must be between 1900-01-01 and 2027-10-30"])
  end

  it "rejects a date with a two digit year" do
    subject.happened_on = "0025-11-12"
    expect(subject).to be_invalid
  end

  it "accepts a date one year from today" do
    subject.happened_on = Date.new(2027, 10, 30)
    expect(subject).to be_valid
  end

  it "rejects a date more than one year from today" do
    subject.happened_on = Date.new(2027, 10, 31)
    expect(subject).to be_invalid
    expect(subject.errors[:happened_on]).to eq(["must be between 1900-01-01 and 2027-10-30"])
  end

  it "rejects a date with a five digit year" do
    subject.happened_on = "72026-10-07"
    expect(subject).to be_invalid
  end
end
