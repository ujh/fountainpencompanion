require "rails_helper"

RSpec.describe CheckInkClustering::Create do
  include ActiveSupport::Testing::TimeHelpers
  before(:each) { WebMock.reset! }

  let(:user) { create(:user) }
  let!(:collected_ink_1) do
    create(:collected_ink, user: user, brand_name: "Diamine", ink_name: "Oxford Blue")
  end
  let!(:collected_ink_2) do
    create(:collected_ink, user: user, brand_name: "Diamine", ink_name: "Oxford Blue Deluxe")
  end
  let!(:micro_cluster) do
    cluster = create(:micro_cluster)
    cluster.collected_inks = [collected_ink_1, collected_ink_2]
    cluster
  end
  let!(:micro_cluster_agent_log) do
    AgentLog.create!(
      name: "InkClusterer",
      owner: micro_cluster,
      transcript: [
        { system: "You are a clustering agent..." },
        { user: "Cluster data..." },
        { assistant: "I'll create a new cluster for this ink" }
      ],
      state: "waiting-for-approval",
      extra_data: {
        "action" => "create_new_cluster",
        "explanation_of_decision" =>
          "This ink doesn't match any existing clusters and should have its own cluster."
      }
    )
  end

  subject { described_class.new(micro_cluster_agent_log.id) }

  describe "#initialize" do
    it "creates agent with micro cluster agent log" do
      agent = described_class.new(micro_cluster_agent_log.id)
      expect(agent.send(:micro_cluster_agent_log)).to eq(micro_cluster_agent_log)
    end

    it "creates child agent log" do
      agent = described_class.new(micro_cluster_agent_log.id)
      child_log = agent.send(:agent_log)
      expect(child_log).to be_persisted
      expect(child_log.name).to eq("CheckInkClustering::Create")
      expect(micro_cluster_agent_log.agent_logs).to include(child_log)
    end

    it "initializes transcript with system directive" do
      agent = described_class.new(micro_cluster_agent_log.id)
      expect(agent.transcript.first[:system]).to be_present
      expect(agent.transcript.first[:system]).to include(
        "reviewing the result of a clustering algorithm"
      )
      expect(agent.transcript.first[:system]).to include("new cluster should be created")
    end

    it "includes clustering explanation in transcript" do
      agent = described_class.new(micro_cluster_agent_log.id)
      explanation_message =
        agent.transcript.find { |msg| msg[:user]&.include?("reasoning of the AI") }
      expect(explanation_message).to be_present
      expect(explanation_message[:user]).to include("doesn't match any existing clusters")
    end

    it "includes micro cluster data in transcript" do
      agent = described_class.new(micro_cluster_agent_log.id)
      cluster_data_message =
        agent.transcript.find { |msg| msg[:user]&.include?("data for the ink to cluster") }
      expect(cluster_data_message).to be_present
      expect(cluster_data_message[:user]).to include("Diamine")
      expect(cluster_data_message[:user]).to include("Oxford Blue")
    end

    context "with existing agent log transcript" do
      let!(:existing_agent_log) do
        micro_cluster_agent_log.agent_logs.create!(
          name: "CheckInkClustering::Create",
          transcript: [{ system: "existing transcript" }]
        )
      end

      it "reuses existing transcript" do
        agent = described_class.new(micro_cluster_agent_log.id)
        expect(agent.transcript.first[:system]).to eq("existing transcript")
      end
    end
  end

  describe "#perform" do
    let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

    context "when approving cluster creation" do
      let(:approve_response) do
        {
          "id" => "chatcmpl-create-123",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_approve_create",
                    "type" => "function",
                    "function" => {
                      "name" => "approve_cluster_creation",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "The cluster creation is correct - this is a unique ink that doesn't match existing clusters."
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 250,
            "completion_tokens" => 35,
            "total_tokens" => 285
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: approve_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "sends correct request to OpenAI" do
        subject.perform

        expect(WebMock).to have_requested(:post, openai_url).at_least_once
      end

      it "updates agent log with approval" do
        subject.perform

        agent_log = subject.send(:agent_log)
        expect(agent_log.extra_data["action"]).to eq("approve")
        expect(agent_log.extra_data["explanation_of_decision"]).to include(
          "The cluster creation is correct"
        )
        expect(agent_log.state).to eq("waiting-for-approval")
      end

      it "updates micro cluster agent log with follow-up data" do
        subject.perform

        micro_cluster_agent_log.reload
        expect(micro_cluster_agent_log.extra_data["follow_up_done"]).to be true
        expect(micro_cluster_agent_log.extra_data["follow_up_action"]).to eq("approve")
        expect(micro_cluster_agent_log.extra_data["follow_up_action_explanation"]).to include(
          "The cluster creation is correct"
        )
      end

      it "calls InkClusterer.approve! when approved" do
        expect_any_instance_of(InkClusterer).to receive(:approve!).with(agent: true)
        subject.perform
      end
    end

    context "when rejecting cluster creation" do
      let(:reject_response) do
        {
          "id" => "chatcmpl-reject-create-123",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_reject_create",
                    "type" => "function",
                    "function" => {
                      "name" => "reject_cluster_creation",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "The cluster creation is incorrect - this ink is just a misspelling of an existing cluster."
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 200,
            "completion_tokens" => 30,
            "total_tokens" => 230
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: reject_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "updates agent log with rejection" do
        subject.perform

        agent_log = subject.send(:agent_log)
        expect(agent_log.extra_data["action"]).to eq("reject")
        expect(agent_log.extra_data["explanation_of_decision"]).to include(
          "The cluster creation is incorrect"
        )
      end

      it "calls InkClusterer.reject! when rejected" do
        expect_any_instance_of(InkClusterer).to receive(:reject!).with(agent: true).and_return([])
        subject.perform
      end

      it "schedules reprocessing jobs for returned clusters" do
        returned_cluster = create(:micro_cluster)
        expect_any_instance_of(InkClusterer).to receive(:reject!).with(agent: true).and_return(
          [returned_cluster]
        )

        subject.perform

        expect(RunInkClustererAgent.jobs.size).to eq(1)
        expect(RunInkClustererAgent.jobs.last["args"]).to eq(["InkClusterer", returned_cluster.id])
      end
    end

    context "with empty micro cluster" do
      let!(:empty_micro_cluster) { create(:micro_cluster) }
      let!(:empty_agent_log) do
        AgentLog.create!(
          name: "InkClusterer",
          owner: empty_micro_cluster,
          transcript: [],
          state: "waiting-for-approval",
          extra_data: {
            "action" => "create_new_cluster",
            "explanation_of_decision" => "Creation explanation"
          }
        )
      end

      subject { described_class.new(empty_agent_log.id) }

      it "rejects empty micro cluster without calling OpenAI" do
        subject.perform

        expect(WebMock).not_to have_requested(:post, openai_url)

        agent_log = subject.send(:agent_log)
        expect(agent_log.extra_data["action"]).to eq("reject")
        expect(agent_log.extra_data["explanation_of_decision"]).to include("no inks in it")
      end
    end

    context "with OpenAI API errors" do
      before do
        stub_request(:post, openai_url).to_return(status: 500, body: "Internal Server Error")
      end

      it "raises API errors as expected" do
        expect { subject.perform }.to raise_error(Faraday::ServerError)
      end
    end

    context "with malformed OpenAI response" do
      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: { "invalid" => "response" }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises errors for malformed responses" do
        expect { subject.perform }.to raise_error(NoMethodError)
      end
    end
  end

  describe "#system_directive" do
    it "returns cluster creation review instructions" do
      directive = subject.send(:system_directive)
      expect(directive).to include("reviewing the result of a clustering algorithm")
      expect(directive).to include("new cluster should be created")
      expect(directive).to include("No ink can be found that is similar enough")
      expect(directive).to include("different spelling of the cluster")
      expect(directive).to include("translation of an existing cluster")
      expect(directive).to include("ink does not exist at all")
      expect(directive).to include("mix of inks")
      expect(directive).to include("known brand names")
      expect(directive).to include("search the web")
      expect(directive).to include("similarity search function")
    end
  end

  describe "function definitions" do
    it "responds to approve_cluster_creation function" do
      expect(subject).to respond_to(:approve_cluster_creation)
    end

    it "responds to reject_cluster_creation function" do
      expect(subject).to respond_to(:reject_cluster_creation)
    end
  end

  describe "integration scenarios" do
    let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

    context "complete approval workflow" do
      let(:approve_response) do
        {
          "id" => "chatcmpl-create-integration-123",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_approve_create_integration",
                    "type" => "function",
                    "function" => {
                      "name" => "approve_cluster_creation",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "Integration test approval for cluster creation"
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 200,
            "completion_tokens" => 30,
            "total_tokens" => 230
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: approve_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "completes full approval workflow" do
        expect_any_instance_of(InkClusterer).to receive(:approve!).with(agent: true)

        subject.perform

        # Verify agent log state
        agent_log = subject.send(:agent_log)
        expect(agent_log.state).to eq("waiting-for-approval")
        expect(agent_log.extra_data["action"]).to eq("approve")

        # Verify micro cluster agent log update
        micro_cluster_agent_log.reload
        expect(micro_cluster_agent_log.extra_data["follow_up_done"]).to be true
        expect(micro_cluster_agent_log.extra_data["follow_up_action"]).to eq("approve")
      end
    end

    context "complete rejection workflow" do
      let(:reject_response) do
        {
          "id" => "chatcmpl-reject-create-integration-123",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_reject_create_integration",
                    "type" => "function",
                    "function" => {
                      "name" => "reject_cluster_creation",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "Integration test rejection for cluster creation"
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 200,
            "completion_tokens" => 30,
            "total_tokens" => 230
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: reject_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "completes full rejection workflow with reprocessing" do
        returned_clusters = [create(:micro_cluster), create(:micro_cluster)]
        expect_any_instance_of(InkClusterer).to receive(:reject!).with(agent: true).and_return(
          returned_clusters
        )

        subject.perform

        # Verify jobs were scheduled for both clusters
        expect(RunInkClustererAgent.jobs.size).to eq(2)
        scheduled_args = RunInkClustererAgent.jobs.map { |job| job["args"] }
        expect(scheduled_args).to include(["InkClusterer", returned_clusters[0].id])
        expect(scheduled_args).to include(["InkClusterer", returned_clusters[1].id])

        # Verify agent log state
        agent_log = subject.send(:agent_log)
        expect(agent_log.state).to eq("waiting-for-approval")
        expect(agent_log.extra_data["action"]).to eq("reject")

        # Verify micro cluster agent log update
        micro_cluster_agent_log.reload
        expect(micro_cluster_agent_log.extra_data["follow_up_done"]).to be true
        expect(micro_cluster_agent_log.extra_data["follow_up_action"]).to eq("reject")
      end
    end

    context "with ink mix scenarios" do
      let!(:mixed_ink) do
        create(
          :collected_ink,
          user: user,
          brand_name: "Custom",
          ink_name: "Pilot Iroshizuku + Diamine Blue"
        )
      end

      let!(:mixed_micro_cluster) do
        cluster = create(:micro_cluster)
        cluster.collected_inks = [mixed_ink]
        cluster
      end

      let!(:mixed_agent_log) do
        AgentLog.create!(
          name: "InkClusterer",
          owner: mixed_micro_cluster,
          transcript: [],
          state: "waiting-for-approval",
          extra_data: {
            "action" => "create_new_cluster",
            "explanation_of_decision" => "This looks like a unique ink"
          }
        )
      end

      subject { described_class.new(mixed_agent_log.id) }

      let(:reject_mix_response) do
        {
          "id" => "chatcmpl-reject-mix-123",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_reject_mix",
                    "type" => "function",
                    "function" => {
                      "name" => "reject_cluster_creation",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "This is a mix of inks and should not have its own cluster."
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 200,
            "completion_tokens" => 30,
            "total_tokens" => 230
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: reject_mix_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "rejects cluster creation for ink mixes" do
        subject.perform

        agent_log = subject.send(:agent_log)
        expect(agent_log.extra_data["action"]).to eq("reject")
        expect(agent_log.extra_data["explanation_of_decision"]).to include("mix of inks")
      end
    end
  end
end
