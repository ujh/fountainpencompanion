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

    describe "remove_orphaned_macro_clusters" do
      let(:uuid_name) { SecureRandom.uuid }

      def orphan(**attrs)
        create(:macro_cluster, brand_name: "", line_name: "", ink_name: uuid_name, **attrs)
      end

      it "removes old macro clusters with a UUID name and no inks" do
        cluster = orphan(created_at: 3.hours.ago)
        described_class.new.perform
        expect(MacroCluster.exists?(cluster.id)).to be false
      end

      it "detaches empty micro clusters from the removed macro cluster" do
        cluster = orphan(created_at: 3.hours.ago)
        micro_cluster = create(:micro_cluster, macro_cluster: cluster)
        described_class.new.perform
        expect(MacroCluster.exists?(cluster.id)).to be false
        expect(micro_cluster.reload.macro_cluster_id).to be_nil
      end

      it "matches the UUID name case insensitively" do
        cluster =
          create(:macro_cluster, ink_name: SecureRandom.uuid.upcase, created_at: 3.hours.ago)
        described_class.new.perform
        expect(MacroCluster.exists?(cluster.id)).to be false
      end

      it "keeps macro clusters younger than two hours" do
        cluster = orphan(created_at: 1.hour.ago)
        described_class.new.perform
        expect(MacroCluster.exists?(cluster.id)).to be true
      end

      it "keeps macro clusters that have inks" do
        cluster = orphan(created_at: 3.hours.ago)
        create(:micro_cluster, macro_cluster: cluster)
        micro_cluster = create(:micro_cluster, macro_cluster: cluster)
        create(:collected_ink, micro_cluster: micro_cluster)
        described_class.new.perform
        expect(MacroCluster.exists?(cluster.id)).to be true
      end

      it "keeps macro clusters that have ink reviews" do
        cluster = orphan(created_at: 3.hours.ago)
        create(:ink_review, macro_cluster: cluster)
        described_class.new.perform
        expect(MacroCluster.exists?(cluster.id)).to be true
      end

      it "keeps macro clusters that have ink review submissions" do
        cluster = orphan(created_at: 3.hours.ago)
        create(:ink_review_submission, macro_cluster: cluster)
        described_class.new.perform
        expect(MacroCluster.exists?(cluster.id)).to be true
      end

      it "keeps old macro clusters without inks that have a real name" do
        cluster = create(:macro_cluster, ink_name: "Kon-peki", created_at: 3.hours.ago)
        described_class.new.perform
        expect(MacroCluster.exists?(cluster.id)).to be true
      end

      it "keeps macro clusters where the UUID is only part of the name" do
        cluster = orphan(ink_name: "Blue #{uuid_name}", created_at: 3.hours.ago)
        described_class.new.perform
        expect(MacroCluster.exists?(cluster.id)).to be true
      end
    end
  end
end
