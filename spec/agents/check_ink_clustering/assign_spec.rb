require "rails_helper"

RSpec.describe CheckInkClustering::Assign do
  include ActiveSupport::Testing::TimeHelpers
  before(:each) { WebMock.reset! }

  let(:user) { create(:user) }
  let!(:collected_ink_1) do
    create(:collected_ink, user: user, brand_name: "Pilot", ink_name: "Iroshizuku Kon-peki")
  end
  let!(:collected_ink_2) do
    create(:collected_ink, user: user, brand_name: "Pilot", ink_name: "Iroshizuku Asa-gao")
  end
  let!(:micro_cluster) do
    cluster = create(:micro_cluster)
    cluster.collected_inks = [collected_ink_1, collected_ink_2]
    cluster
  end
  let!(:macro_cluster) do
    create(:macro_cluster, brand_name: "Pilot", line_name: "Iroshizuku", ink_name: "Kon-peki")
  end
  let!(:macro_cluster_collected_ink) do
    create(:collected_ink, user: user, brand_name: "Pilot", ink_name: "Iroshizuku Kon-peki")
  end
  let!(:macro_cluster_micro_cluster) do
    cluster = create(:micro_cluster, macro_cluster: macro_cluster)
    cluster.collected_inks = [macro_cluster_collected_ink]
    cluster
  end

  let!(:micro_cluster_agent_log) do
    AgentLog.create!(
      name: "InkClusterer",
      owner: micro_cluster,
      transcript: [
        { system: "You are a clustering agent..." },
        { user: "Cluster data..." },
        { assistant: "I'll assign this to cluster #{macro_cluster.id}" }
      ],
      state: "waiting-for-approval",
      extra_data: {
        "action" => "assign_to_cluster",
        "cluster_id" => macro_cluster.id,
        "explanation_of_decision" =>
          "These are both Pilot Iroshizuku blue inks that belong together."
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
      expect(child_log.name).to eq("CheckInkClustering::Assign")
      expect(micro_cluster_agent_log.agent_logs).to include(child_log)
    end

    it "initializes transcript with system directive" do
      agent = described_class.new(micro_cluster_agent_log.id)
      expect(agent.transcript.first[:system]).to be_present
      expect(agent.transcript.first[:system]).to include(
        "reviewing the result of a clustering algorithm"
      )
      expect(agent.transcript.first[:system]).to include("assigned to an existing cluster")
    end

    it "includes clustering explanation in transcript" do
      agent = described_class.new(micro_cluster_agent_log.id)
      explanation_message =
        agent.transcript.find { |msg| msg[:user]&.include?("reasoning of the AI") }
      expect(explanation_message).to be_present
      expect(explanation_message[:user]).to include("These are both Pilot Iroshizuku blue inks")
    end

    it "includes micro cluster data in transcript" do
      agent = described_class.new(micro_cluster_agent_log.id)
      cluster_data_message =
        agent.transcript.find { |msg| msg[:user]&.include?("data for the ink to cluster") }
      expect(cluster_data_message).to be_present
      expect(cluster_data_message[:user]).to include("Pilot")
      expect(cluster_data_message[:user]).to include("Iroshizuku")
    end

    it "includes macro cluster data in transcript" do
      agent = described_class.new(micro_cluster_agent_log.id)
      macro_data_message =
        agent.transcript.find do |msg|
          msg[:user]&.include?("cluster to which the ink was assigned")
        end
      expect(macro_data_message).to be_present
      expect(macro_data_message[:user]).to include("Iroshizuku Kon-peki")
    end

    context "with existing agent log transcript" do
      let!(:existing_agent_log) do
        micro_cluster_agent_log.agent_logs.create!(
          name: "CheckInkClustering::Assign",
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

    context "when approving assignment" do
      let(:approve_response) do
        {
          "id" => "chatcmpl-assign-123",
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
                    "id" => "call_approve",
                    "type" => "function",
                    "function" => {
                      "name" => "approve_assignment",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "The assignment is correct - both inks are Pilot Iroshizuku blues."
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

      it "sends correct request to OpenAI" do
        subject.perform

        expect(WebMock).to have_requested(:post, openai_url).at_least_once
      end

      it "updates agent log with approval" do
        subject.perform

        agent_log = subject.send(:agent_log)
        expect(agent_log.extra_data["action"]).to eq("approve")
        expect(agent_log.extra_data["explanation_of_decision"]).to include(
          "The assignment is correct"
        )
        expect(agent_log.state).to eq("waiting-for-approval")
      end

      it "updates micro cluster agent log with follow-up data" do
        subject.perform

        micro_cluster_agent_log.reload
        expect(micro_cluster_agent_log.extra_data["follow_up_done"]).to be true
        expect(micro_cluster_agent_log.extra_data["follow_up_action"]).to eq("approve")
        expect(micro_cluster_agent_log.extra_data["follow_up_action_explanation"]).to include(
          "The assignment is correct"
        )
      end

      it "calls InkClusterer.approve! when approved" do
        expect_any_instance_of(InkClusterer).to receive(:approve!).with(agent: true)
        subject.perform
      end
    end

    context "when rejecting assignment" do
      let(:reject_response) do
        {
          "id" => "chatcmpl-reject-123",
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
                    "id" => "call_reject",
                    "type" => "function",
                    "function" => {
                      "name" => "reject_assignment",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "The assignment is incorrect - these are different ink types."
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
          "The assignment is incorrect"
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
            "action" => "assign_to_cluster",
            "cluster_id" => macro_cluster.id,
            "explanation_of_decision" => "Assignment explanation"
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
    it "returns assignment review instructions" do
      directive = subject.send(:system_directive)
      expect(directive).to include("reviewing the result of a clustering algorithm")
      expect(directive).to include("assigned to an existing cluster")
      expect(directive).to include("different spelling of the cluster")
      expect(directive).to include("translation of the cluster")
      expect(directive).to include("RGB color")
      expect(directive).to include("search the web")
      expect(directive).to include("similarity search function")
    end
  end

  describe "#macro_cluster_data" do
    it "returns formatted macro cluster data" do
      data = subject.send(:macro_cluster_data)
      expect(data).to include("cluster to which the ink was assigned")
      expect(data).to include("Iroshizuku Kon-peki")
      expect(data).to include("names")
      expect(data).to include("names_as_elements")
    end
  end

  describe "function definitions" do
    it "responds to approve_assignment function" do
      expect(subject).to respond_to(:approve_assignment)
    end

    it "responds to reject_assignment function" do
      expect(subject).to respond_to(:reject_assignment)
    end
  end

  describe "integration scenarios" do
    let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

    context "complete approval workflow" do
      let(:approve_response) do
        {
          "id" => "chatcmpl-integration-123",
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
                    "id" => "call_approve_integration",
                    "type" => "function",
                    "function" => {
                      "name" => "approve_assignment",
                      "arguments" => {
                        "explanation_of_decision" => "Integration test approval"
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
          "id" => "chatcmpl-reject-integration-123",
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
                    "id" => "call_reject_integration",
                    "type" => "function",
                    "function" => {
                      "name" => "reject_assignment",
                      "arguments" => {
                        "explanation_of_decision" => "Integration test rejection"
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
  end
end
