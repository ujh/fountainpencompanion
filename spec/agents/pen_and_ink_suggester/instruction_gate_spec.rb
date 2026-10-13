require "rails_helper"

RSpec.describe PenAndInkSuggester::InstructionGate do
  include ActiveSupport::Testing::TimeHelpers

  subject(:gate) { described_class.new(user) }

  let(:user) { create(:user, confirmed_at: 1.month.ago) }

  before { freeze_time }
  after { travel_back }

  context "with more than 20 inks" do
    before { create_list(:collected_ink, 21, user:) }

    it "is allowed when the account was confirmed more than 2 weeks ago" do
      user.update!(confirmed_at: 2.weeks.ago - 1.second)

      expect(gate).to be_allowed
    end

    it "is not allowed when the account was confirmed exactly 2 weeks ago" do
      user.update!(confirmed_at: 2.weeks.ago)

      expect(gate).not_to be_allowed
    end

    it "is not allowed when the account was confirmed less than 2 weeks ago" do
      user.update!(confirmed_at: 2.weeks.ago + 1.second)

      expect(gate).not_to be_allowed
    end

    it "is not allowed when the account is not confirmed" do
      user.update_column(:confirmed_at, nil)

      expect(gate).not_to be_allowed
    end
  end

  it "is not allowed with 20 inks and 20 pens" do
    create_list(:collected_ink, 20, user:)
    create_list(:collected_pen, 20, user:)

    expect(gate).not_to be_allowed
  end

  it "is allowed with 21 pens" do
    create_list(:collected_pen, 21, user:)

    expect(gate).to be_allowed
  end

  it "counts archived inks" do
    create_list(:collected_ink, 20, user:)
    create(:collected_ink, user:, archived_on: Date.current)

    expect(gate).to be_allowed
  end

  it "counts archived pens" do
    create_list(:collected_pen, 20, user:)
    create(:collected_pen, user:, archived_on: Date.current)

    expect(gate).to be_allowed
  end

  it "does not add up inks and pens" do
    create_list(:collected_ink, 11, user:)
    create_list(:collected_pen, 11, user:)

    expect(gate).not_to be_allowed
  end

  it "does not count another user's items" do
    create_list(:collected_ink, 21)
    create_list(:collected_pen, 21)

    expect(gate).not_to be_allowed
  end
end
