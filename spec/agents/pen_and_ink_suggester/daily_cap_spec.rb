require "rails_helper"

RSpec.describe PenAndInkSuggester::DailyCap do
  subject(:daily_cap) { described_class.new(user) }

  let(:user) { create(:user) }

  def create_logs(count, **attributes)
    create_list(:agent_log, count, name: "PenAndInkSuggester", owner: user, **attributes)
  end

  context "for a free user" do
    it "is not reached after 19 runs today" do
      create_logs(19)

      expect(daily_cap).not_to be_reached
    end

    it "is reached after 20 runs today" do
      create_logs(20)

      expect(daily_cap).to be_reached
    end

    it "points to Patreon in the message" do
      expect(daily_cap.message).to eq(
        "You have reached your daily limit of 20 suggestions. Consider becoming a [Patron](https://www.patreon.com/bePatron?u=6900241) for a higher limit!"
      )
    end
  end

  context "for a patron" do
    before { user.update!(patron: true) }

    it "is not reached after 49 runs today" do
      create_logs(49)

      expect(daily_cap).not_to be_reached
    end

    it "is reached after 50 runs today" do
      create_logs(50)

      expect(daily_cap).to be_reached
    end

    it "asks to try again tomorrow in the message" do
      expect(daily_cap.message).to eq(
        "You have reached your daily limit of 50 suggestions. Please try again tomorrow."
      )
    end
  end

  it "gives admins the patron limit" do
    user.update!(admin: true)
    create_logs(49)

    expect(daily_cap).not_to be_reached
  end

  it "ignores runs from previous days" do
    create_logs(20, created_at: 1.day.ago.end_of_day)

    expect(daily_cap).not_to be_reached
  end

  it "ignores precheck runs" do
    create_logs(20, extra_data: { message: "No pens", precheck: "no_uninked_pens" })

    expect(daily_cap).not_to be_reached
  end

  it "counts error runs" do
    create_logs(20, extra_data: { message: "Sorry", error: "DecisionNotReachedError" })

    expect(daily_cap).to be_reached
  end

  it "ignores other agents' logs" do
    create_list(:agent_log, 20, name: "SpamClassifier", owner: user)

    expect(daily_cap).not_to be_reached
  end

  it "ignores other users' runs" do
    create_list(:agent_log, 20, name: "PenAndInkSuggester", owner: create(:user))

    expect(daily_cap).not_to be_reached
  end
end
