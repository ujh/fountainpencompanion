require "rails_helper"

describe Admins::AgentLogsController do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe "GET /admins/agent_logs" do
    context "when not authenticated" do
      it "redirects to login" do
        get "/admins/agent_logs"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as regular user" do
      before { sign_in(regular_user) }

      it "redirects to login" do
        get "/admins/agent_logs"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as admin" do
      before { sign_in(admin) }

      context "with no agent logs" do
        it "renders successfully" do
          get "/admins/agent_logs"
          expect(response).to be_successful
        end

        it "assigns empty collections" do
          get "/admins/agent_logs"
          expect(assigns(:agent_logs)).to be_empty
          expect(assigns(:agent_log_names)).to be_empty
        end
      end

      context "with agent logs" do
        let!(:ink_clusterer_log_1) do
          create(:agent_log, name: "InkClusterer", created_at: 2.days.ago)
        end

        let!(:ink_clusterer_log_2) do
          create(:agent_log, name: "InkClusterer", created_at: 1.day.ago)
        end

        let!(:spam_classifier_log) do
          create(:agent_log, name: "SpamClassifier", created_at: 3.days.ago)
        end

        it "renders successfully" do
          get "/admins/agent_logs"
          expect(response).to be_successful
        end

        it "orders agent logs by created_at desc" do
          get "/admins/agent_logs"
          agent_logs = assigns(:agent_logs)
          expect(agent_logs.map(&:id)).to eq([ink_clusterer_log_2.id])
        end

        it "paginates with 1 per page" do
          get "/admins/agent_logs"
          agent_logs = assigns(:agent_logs)
          expect(agent_logs.size).to eq(1)
          expect(agent_logs.current_page).to eq(1)
        end

        it "includes agent log names with counts" do
          get "/admins/agent_logs"
          agent_log_names = assigns(:agent_log_names)
          expect(agent_log_names).to eq(
            { "InkClusterer (2)" => "InkClusterer", "SpamClassifier (1)" => "SpamClassifier" }
          )
        end

        context "with pagination" do
          it "returns second page when requested" do
            get "/admins/agent_logs", params: { page: 2 }
            agent_logs = assigns(:agent_logs)
            expect(agent_logs.map(&:id)).to eq([ink_clusterer_log_1.id])
            expect(agent_logs.current_page).to eq(2)
          end
        end

        context "with name filter" do
          it "filters by name when provided" do
            get "/admins/agent_logs", params: { name: "InkClusterer" }
            agent_logs = assigns(:agent_logs)
            expect(agent_logs.map(&:name)).to all eq("InkClusterer")
            expect(agent_logs.size).to eq(1)
          end

          it "filters by different name" do
            get "/admins/agent_logs", params: { name: "SpamClassifier" }
            agent_logs = assigns(:agent_logs)
            expect(agent_logs.map(&:name)).to all eq("SpamClassifier")
            expect(agent_logs.map(&:id)).to eq([spam_classifier_log.id])
          end

          it "returns empty result for non-existent name" do
            get "/admins/agent_logs", params: { name: "NonExistentAgent" }
            agent_logs = assigns(:agent_logs)
            expect(agent_logs).to be_empty
          end

          it "ignores empty name parameter" do
            get "/admins/agent_logs", params: { name: "" }
            agent_logs = assigns(:agent_logs)
            expect(agent_logs.size).to eq(1)
            expect(agent_logs.map(&:id)).to eq([ink_clusterer_log_2.id])
          end
        end

        context "combining filters and pagination" do
          let!(:additional_ink_clusterer_log) do
            create(:agent_log, name: "InkClusterer", created_at: Time.current)
          end

          it "applies both name filter and pagination" do
            get "/admins/agent_logs", params: { name: "InkClusterer", page: 2 }
            agent_logs = assigns(:agent_logs)
            expect(agent_logs.map(&:name)).to all eq("InkClusterer")
            expect(agent_logs.current_page).to eq(2)
            expect(agent_logs.map(&:id)).to eq([ink_clusterer_log_2.id])
          end
        end
      end
    end
  end
end
