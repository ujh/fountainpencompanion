require "rails_helper"

describe AdminStats do
  describe "#micro_cluster_agent_review_count" do
    it "ignores logs whose micro cluster has no collected inks" do
      ink = create(:collected_ink)
      with_inks = create(:micro_cluster)
      with_inks.collected_inks = [ink]
      empty = create(:micro_cluster)

      AgentLog.create!(
        name: "InkClusterer",
        owner: with_inks,
        transcript: [],
        state: AgentLog::WAITING_FOR_APPROVAL
      )
      AgentLog.create!(
        name: "InkClusterer",
        owner: empty,
        transcript: [],
        state: AgentLog::WAITING_FOR_APPROVAL
      )

      expect(described_class.new.micro_cluster_agent_review_count).to eq(1)
    end
  end

  describe "#open_error_reports_count" do
    it "counts the reports that are not resolved" do
      create_list(:error_report, 2)
      create(:error_report, resolved_at: Time.current)

      expect(described_class.new.open_error_reports_count).to eq(2)
    end
  end
end
