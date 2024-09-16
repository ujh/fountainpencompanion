require "rails_helper"

describe SpamClassifier do
  let(:user) { create(:user) }

  context "user classified as spam" do
    before do
      allow_any_instance_of(Bots::SpamClassifier).to receive(:run).and_return(
        true
      )
      described_class.new.perform(user.id)
      user.reload
    end

    it "sets the spam boolean to true" do
      expect(user.spam).to eq(true)
    end

    it "sets the spam_reason correctly" do
      expect(user.spam_reason).to eq("auto-spam")
    end
  end

  context "user not classified as spam" do
    before do
      allow_any_instance_of(Bots::SpamClassifier).to receive(:run).and_return(
        false
      )
      described_class.new.perform(user.id)
      user.reload
    end

    it "sets the spam boolean to true" do
      expect(user.spam).to eq(false)
    end

    it "sets the spam_reason correctly" do
      expect(user.spam_reason).to eq("auto-not-spam")
    end
  end
end
