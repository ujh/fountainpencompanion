require "rails_helper"

describe Admins::Agents::InkClustererController do
  let(:admin) { create(:user, :admin) }

  describe "#show" do
    it "requires authentication" do
      get "/admins/agents/ink_clusterer"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders successfully" do
        get "/admins/agents/ink_clusterer"
        expect(response).to be_successful
      end
    end
  end

  describe "#destroy" do
    let(:user) { create(:user) }
    let!(:collected_ink) { create(:collected_ink, user: user) }
    let!(:micro_cluster) do
      cluster = create(:micro_cluster)
      cluster.collected_inks = [collected_ink]
      cluster
    end
    let!(:agent_log) do
      AgentLog.create!(
        name: "InkClusterer",
        owner: micro_cluster,
        transcript: [],
        state: "waiting-for-approval",
        extra_data: {
          "action" => "assign_to_cluster",
          "cluster_id" => 99,
          "explanation_of_decision" => "Initial reasoning"
        }
      )
    end

    before(:each) { sign_in(admin) }

    it "persists the manual_rejection_note on the agent log" do
      delete "/admins/agents/ink_clusterer/#{agent_log.id}",
             params: {
               manual_rejection_note: "Color is clearly different"
             }

      expect(agent_log.reload.extra_data["manual_rejection_note"]).to eq(
        "Color is clearly different"
      )
      expect(agent_log.extra_data["explanation_of_decision"]).to eq("Initial reasoning")
      expect(agent_log.state).to eq(AgentLog::REJECTED)
    end

    it "ignores blank/whitespace-only notes" do
      delete "/admins/agents/ink_clusterer/#{agent_log.id}",
             params: {
               manual_rejection_note: "   "
             }

      expect(agent_log.reload.extra_data).not_to have_key("manual_rejection_note")
      expect(agent_log.state).to eq(AgentLog::REJECTED)
    end

    it "still works without a note param" do
      delete "/admins/agents/ink_clusterer/#{agent_log.id}"

      expect(agent_log.reload.extra_data).not_to have_key("manual_rejection_note")
      expect(agent_log.state).to eq(AgentLog::REJECTED)
    end

    context "when the agent already approved" do
      before do
        agent_log.update!(
          state: AgentLog::APPROVED,
          agent_approved: true,
          approved_at: Time.current
        )
      end

      it "persists the note and reprocesses" do
        delete "/admins/agents/ink_clusterer/#{agent_log.id}",
               params: {
                 manual_rejection_note: "Wrong cluster"
               }

        expect(agent_log.reload.extra_data["manual_rejection_note"]).to eq("Wrong cluster")
        expect(agent_log.state).to eq(AgentLog::REJECTED)
      end
    end

    context "when the agent already rejected" do
      before do
        agent_log.update!(
          state: AgentLog::APPROVED,
          agent_approved: true,
          approved_at: Time.current
        )
        agent_log.update!(state: "rejected", rejected_at: Time.current)
      end

      it "still attaches the note even though no reprocess is triggered" do
        delete "/admins/agents/ink_clusterer/#{agent_log.id}",
               params: {
                 manual_rejection_note: "Confirming the rejection"
               }

        expect(agent_log.reload.extra_data["manual_rejection_note"]).to eq(
          "Confirming the rejection"
        )
      end
    end
  end
end
