require "rails_helper"

describe RunFailedClusterJobs do
  describe "#perform" do
    it "preserves processing ink_clusterer agent logs so the transcript is reused" do
      cluster = create(:micro_cluster)
      log =
        create(:agent_log, :ink_clusterer, :processing, owner: cluster, created_at: 30.minutes.ago)

      described_class.new.perform

      expect(AgentLog.exists?(log.id)).to be true
    end

    it "enqueues a new RunInkClustererAgent job for the cluster" do
      cluster = create(:micro_cluster)
      create(:agent_log, :ink_clusterer, :processing, owner: cluster, created_at: 30.minutes.ago)

      described_class.new.perform

      expect(RunInkClustererAgent.jobs.size).to eq(1)
      expect(RunInkClustererAgent.jobs.first["args"]).to eq(["InkClusterer", cluster.id])
    end

    it "does not restart processing logs less than 15 minutes old" do
      cluster = create(:micro_cluster)
      log =
        create(:agent_log, :ink_clusterer, :processing, owner: cluster, created_at: 5.minutes.ago)

      described_class.new.perform

      expect(AgentLog.exists?(log.id)).to be true
      expect(RunInkClustererAgent.jobs.size).to eq(0)
    end

    it "does not restart non-processing ink_clusterer logs" do
      cluster = create(:micro_cluster)
      log = create(:agent_log, :ink_clusterer, :approved, owner: cluster, created_at: 2.hours.ago)

      described_class.new.perform

      expect(AgentLog.exists?(log.id)).to be true
      expect(RunInkClustererAgent.jobs.size).to eq(0)
    end

    it "does not restart processing logs for other agent types" do
      cluster = create(:micro_cluster)
      log =
        create(:agent_log, :processing, name: "OtherAgent", owner: cluster, created_at: 2.hours.ago)

      described_class.new.perform

      expect(AgentLog.exists?(log.id)).to be true
      expect(RunInkClustererAgent.jobs.size).to eq(0)
    end
  end
end
