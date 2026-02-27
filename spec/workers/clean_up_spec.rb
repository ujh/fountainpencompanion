require "rails_helper"

describe CleanUp do
  describe "#perform" do
    describe "clear_expired_deletion_requests" do
      it "clears deletion_requested_at older than 24 hours" do
        user = create(:user, deletion_requested_at: 25.hours.ago)
        described_class.new.perform
        expect(user.reload.deletion_requested_at).to be_nil
      end

      it "does not clear deletion_requested_at within 24 hours" do
        user = create(:user, deletion_requested_at: 23.hours.ago)
        described_class.new.perform
        expect(user.reload.deletion_requested_at).to be_present
      end
    end
  end
end
