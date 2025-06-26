require "rails_helper"

RSpec.describe InkClusterer do
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
  let!(:existing_macro_cluster) do
    create(:macro_cluster, brand_name: "Pilot", line_name: "Blue", ink_name: "Inks")
  end
  let!(:existing_micro_cluster) { create(:micro_cluster, macro_cluster: existing_macro_cluster) }

  subject { described_class.new(micro_cluster.id) }

  describe "#initialize" do
    it "creates agent with micro cluster" do
      clusterer = described_class.new(micro_cluster.id)
      expect(clusterer.agent_log.owner).to eq(micro_cluster)
      expect(clusterer.agent_log.name).to eq("InkClusterer")
      expect(clusterer.agent_log).to be_persisted
    end

    it "accepts optional agent_log_id" do
      agent_log = AgentLog.create!(name: "InkClusterer", transcript: [])
      clusterer = described_class.new(micro_cluster.id, agent_log_id: agent_log.id)
      expect(clusterer.agent_log).to eq(agent_log)
    end

    it "initializes transcript with system directive" do
      clusterer = described_class.new(micro_cluster.id)
      expect(clusterer.transcript.first[:system]).to be_present
      expect(clusterer.transcript.first[:system]).to include("clustering algorithm")
    end

    it "includes micro cluster data in transcript" do
      clusterer = described_class.new(micro_cluster.id)
      user_message = clusterer.transcript.find { |msg| msg[:user] }[:user]
      expect(user_message).to include(micro_cluster.id.to_s)
      expect(user_message).to include("Pilot")
      expect(user_message).to include("Iroshizuku")
    end

    context "with processed tries" do
      let!(:rejected_log) do
        AgentLog.create!(
          name: "InkClusterer",
          owner: micro_cluster,
          transcript: [],
          state: "rejected",
          extra_data: {
            "action" => "assign_to_cluster",
            "cluster_id" => existing_macro_cluster.id
          },
          created_at: 1.hour.ago
        )
      end

      it "includes processed tries data in transcript" do
        clusterer = described_class.new(micro_cluster.id)
        processed_tries_message = clusterer.transcript.select { |msg| msg[:user] }.last[:user]
        expect(processed_tries_message).to include("processed before")
        expect(processed_tries_message).to include("Assigning ink to existing cluster")
      end
    end
  end

  describe "#agent_log" do
    it "creates and memoizes agent log" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to be_persisted
      expect(log1.name).to eq("InkClusterer")
      expect(log1.owner).to eq(micro_cluster)
      expect(log1).to eq(log2)
    end

    it "finds existing processing agent log" do
      existing_log =
        AgentLog.create!(
          name: "InkClusterer",
          owner: micro_cluster,
          transcript: [],
          state: "processing"
        )
      clusterer = described_class.new(micro_cluster.id)
      expect(clusterer.agent_log).to eq(existing_log)
    end

    it "finds existing waiting_for_approval agent log" do
      existing_log =
        AgentLog.create!(
          name: "InkClusterer",
          owner: micro_cluster,
          transcript: [],
          state: "waiting-for-approval"
        )
      clusterer = described_class.new(micro_cluster.id)
      expect(clusterer.agent_log).to eq(existing_log)
    end
  end

  describe "#perform" do
    let(:assign_to_cluster_response) do
      {
        "id" => "chatcmpl-123",
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
                  "id" => "call_123",
                  "type" => "function",
                  "function" => {
                    "name" => "assign_to_cluster",
                    "arguments" => {
                      "cluster_id" => existing_macro_cluster.id,
                      "explanation_of_decision" =>
                        "These are both Pilot Iroshizuku blue inks that belong together."
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 300,
          "completion_tokens" => 50,
          "total_tokens" => 350
        }
      }
    end

    let(:create_new_cluster_response) do
      {
        "id" => "chatcmpl-456",
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
                  "id" => "call_456",
                  "type" => "function",
                  "function" => {
                    "name" => "create_new_cluster",
                    "arguments" => {
                      "explanation_of_decision" =>
                        "This is a unique ink that doesn't match any existing clusters."
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
          "completion_tokens" => 40,
          "total_tokens" => 290
        }
      }
    end

    context "with inks in micro cluster" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: assign_to_cluster_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "performs clustering and updates agent log" do
        expect { subject.perform }.to change { subject.agent_log.reload.state }.to(
          "waiting-for-approval"
        )

        expect(subject.agent_log.extra_data["action"]).to eq("assign_to_cluster")
        expect(subject.agent_log.extra_data["cluster_id"]).to eq(existing_macro_cluster.id)
        expect(subject.agent_log.extra_data["explanation_of_decision"]).to include(
          "Pilot Iroshizuku"
        )
      end

      it "schedules follow-up agent" do
        subject.perform
        expect(subject.agent_log.extra_data["follow_up_agent"]).to eq("CheckInkClustering::Assign")
        expect(RunInkClustererAgent.jobs.size).to eq(1)
        expect(RunInkClustererAgent.jobs.last["args"]).to eq(
          ["CheckInkClustering::Assign", subject.agent_log.id]
        )
      end

      it "uses correct OpenAI model" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            expect(body["model"]).to eq("gpt-4.1")
            true
          }
          .at_least_once
      end

      it "includes all required function definitions" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            if body["tools"].present?
              tool_names = body["tools"].map { |tool| tool["function"]["name"] }
              expect(tool_names).to include("assign_to_cluster")
              expect(tool_names).to include("create_new_cluster")
              expect(tool_names).to include("ignore_ink")
              expect(tool_names).to include("hand_over_to_human")
              expect(tool_names).to include("known_brand")
            end
            true
          }
          .at_least_once
      end
    end

    context "with empty micro cluster" do
      let(:empty_micro_cluster) { create(:micro_cluster) }
      subject { described_class.new(empty_micro_cluster.id) }

      it "rejects with explanation for empty cluster" do
        subject.perform

        expect(subject.agent_log.extra_data["action"]).to eq("reject")
        expect(subject.agent_log.extra_data["explanation_of_decision"]).to include("no inks in it")
        expect(subject.agent_log.state).to eq("approved")
        expect(subject.agent_log.agent_approved).to be true
      end

      it "does not make OpenAI request for empty cluster" do
        subject.perform
        expect(WebMock).not_to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        expect(RunInkClustererAgent.jobs.size).to eq(0)
      end
    end

    context "with create new cluster response" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: create_new_cluster_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "schedules create cluster follow-up" do
        subject.perform
        expect(subject.agent_log.extra_data["follow_up_agent"]).to eq("CheckInkClustering::Create")
        expect(RunInkClustererAgent.jobs.size).to eq(1)
        expect(RunInkClustererAgent.jobs.last["args"]).to eq(
          ["CheckInkClustering::Create", subject.agent_log.id]
        )
      end
    end

    context "with ignore ink response" do
      let(:ignore_ink_response) do
        {
          "id" => "chatcmpl-789",
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
                    "id" => "call_789",
                    "type" => "function",
                    "function" => {
                      "name" => "ignore_ink",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "This appears to be a custom ink mix, not a commercial ink."
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

      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: ignore_ink_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "schedules ignore follow-up" do
        subject.perform
        expect(subject.agent_log.extra_data["follow_up_agent"]).to eq("CheckInkClustering::Ignore")
        expect(RunInkClustererAgent.jobs.size).to eq(1)
        expect(RunInkClustererAgent.jobs.last["args"]).to eq(
          ["CheckInkClustering::Ignore", subject.agent_log.id]
        )
      end
    end

    context "with hand over to human response" do
      let(:hand_over_response) do
        {
          "id" => "chatcmpl-abc",
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
                    "id" => "call_abc",
                    "type" => "function",
                    "function" => {
                      "name" => "hand_over_to_human",
                      "arguments" => {}.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 180,
            "completion_tokens" => 20,
            "total_tokens" => 200
          }
        }
      end

      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: hand_over_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "schedules human follow-up" do
        subject.perform
        expect(subject.agent_log.extra_data["follow_up_agent"]).to eq("CheckInkClustering::Human")
        expect(RunInkClustererAgent.jobs.size).to eq(1)
        expect(RunInkClustererAgent.jobs.last["args"]).to eq(
          ["CheckInkClustering::Human", subject.agent_log.id]
        )
      end
    end
  end

  describe "function validation through OpenAI responses" do
    context "when AI calls assign_to_cluster with valid data" do
      let(:valid_assign_response) do
        {
          "id" => "chatcmpl-assign",
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
                    "id" => "call_assign",
                    "type" => "function",
                    "function" => {
                      "name" => "assign_to_cluster",
                      "arguments" => {
                        "cluster_id" => existing_macro_cluster.id,
                        "explanation_of_decision" => "These inks are similar"
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 100,
            "completion_tokens" => 50,
            "total_tokens" => 150
          }
        }
      end

      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: valid_assign_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "processes valid cluster assignment" do
        subject.perform

        expect(subject.agent_log.extra_data["action"]).to eq("assign_to_cluster")
        expect(subject.agent_log.extra_data["cluster_id"]).to eq(existing_macro_cluster.id)
        expect(subject.agent_log.extra_data["explanation_of_decision"]).to include("similar")
      end
    end

    context "when AI calls assign_to_cluster with invalid cluster ID" do
      let(:invalid_assign_response) do
        {
          "id" => "chatcmpl-invalid",
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
                    "id" => "call_invalid",
                    "type" => "function",
                    "function" => {
                      "name" => "assign_to_cluster",
                      "arguments" => {
                        "cluster_id" => 99_999,
                        "explanation_of_decision" => "Test explanation"
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 100,
            "completion_tokens" => 50,
            "total_tokens" => 150
          }
        }
      end

      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: invalid_assign_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles invalid cluster ID gracefully" do
        # This should not crash and should continue processing
        expect { subject.perform }.not_to raise_error
      end
    end
  end

  describe "#approve!" do
    context "assign_to_cluster action" do
      before do
        subject.agent_log.update!(
          extra_data: {
            "action" => "assign_to_cluster",
            "cluster_id" => existing_macro_cluster.id
          }
        )
      end

      it "assigns micro cluster to macro cluster" do
        subject.approve!

        expect(micro_cluster.reload.macro_cluster).to eq(existing_macro_cluster)
        expect(subject.agent_log.state).to eq("approved")
        expect(UpdateMicroCluster.jobs.size).to eq(1)
        expect(UpdateMicroCluster.jobs.last["args"]).to eq([micro_cluster.id])
      end

      it "can be approved by agent" do
        subject.approve!(agent: true)
        expect(subject.agent_log.reload.state).to eq("approved")
        expect(subject.agent_log.agent_approved).to be true
      end
    end

    context "create_new_cluster action" do
      before { subject.agent_log.update!(extra_data: { "action" => "create_new_cluster" }) }

      it "creates new macro cluster and assigns micro cluster" do
        expect { subject.approve! }.to change { MacroCluster.count }.by(1)

        expect(micro_cluster.reload.macro_cluster).to be_present
        expect(subject.agent_log.state).to eq("approved")
        expect(UpdateMicroCluster.jobs.size).to eq(1)
        expect(UpdateMicroCluster.jobs.last["args"]).to eq([micro_cluster.id])
      end
    end

    context "ignore_ink action" do
      before { subject.agent_log.update!(extra_data: { "action" => "ignore_ink" }) }

      it "marks micro cluster as ignored" do
        subject.approve!

        expect(micro_cluster.reload.ignored).to be true
        expect(subject.agent_log.state).to eq("approved")
      end
    end

    context "hand_over_to_human action" do
      before { subject.agent_log.update!(extra_data: { "action" => "hand_over_to_human" }) }

      it "touches micro cluster and approves" do
        original_updated_at = micro_cluster.updated_at

        travel_to(1.minute.from_now) { subject.approve! }

        expect(micro_cluster.reload.updated_at).to be > original_updated_at
        expect(subject.agent_log.state).to eq("approved")
      end
    end
  end

  describe "#reject!" do
    context "assign_to_cluster action that was approved" do
      let!(:assigned_cluster) { create(:macro_cluster) }

      before do
        micro_cluster.update!(macro_cluster: assigned_cluster)
        subject.agent_log.update!(
          state: "approved",
          extra_data: {
            "action" => "assign_to_cluster",
            "cluster_id" => assigned_cluster.id
          }
        )
      end

      it "removes assignment and returns micro clusters to reprocess" do
        to_reprocess = subject.reject!

        expect(micro_cluster.reload.macro_cluster).to be_nil
        expect(subject.agent_log.state).to eq("rejected")
        expect(to_reprocess).to include(micro_cluster)
      end

      it "can be rejected by agent" do
        subject.reject!(agent: true)
        expect(subject.agent_log.reload.state).to eq("rejected")
        expect(subject.agent_log.agent_approved).to be true
      end
    end

    context "create_new_cluster action that was approved" do
      let!(:created_cluster) { create(:macro_cluster) }

      before do
        micro_cluster.update!(macro_cluster: created_cluster)
        subject.agent_log.update!(
          state: "approved",
          extra_data: {
            "action" => "create_new_cluster"
          }
        )
      end

      it "destroys created cluster and returns affected micro clusters" do
        expect { subject.reject! }.to change { MacroCluster.count }.by(-1)
        expect(subject.agent_log.state).to eq("rejected")
      end
    end

    context "ignore_ink action that was approved" do
      before do
        micro_cluster.update!(ignored: true)
        subject.agent_log.update!(state: "approved", extra_data: { "action" => "ignore_ink" })
      end

      it "unmarks ignored status" do
        subject.reject!

        expect(micro_cluster.reload.ignored).to be false
        expect(subject.agent_log.state).to eq("rejected")
      end
    end

    it "filters out empty micro clusters from reprocessing list" do
      empty_cluster = create(:micro_cluster)
      micro_cluster.update!(macro_cluster: existing_macro_cluster)
      subject.agent_log.update!(
        state: "approved",
        extra_data: {
          "action" => "assign_to_cluster",
          "cluster_id" => existing_macro_cluster.id
        }
      )

      # Mock the clean_up_rejected_approval! method to return both clusters
      allow(subject).to receive(:clean_up_rejected_approval!).and_return(
        [micro_cluster, empty_cluster]
      )

      to_reprocess = subject.reject!

      expect(to_reprocess).not_to include(empty_cluster)
      expect(to_reprocess).to include(micro_cluster)
    end
  end

  describe "data formatting" do
    it "includes micro cluster data in JSON format" do
      clusterer = described_class.new(micro_cluster.id)
      data_message =
        clusterer.transcript.find { |msg| msg[:user] && msg[:user].include?("data for the ink") }[
          :user
        ]

      parsed_data = JSON.parse(data_message.split("This is the data for the ink to cluster: ").last)

      expect(parsed_data["id"]).to eq(micro_cluster.id)
      expect(parsed_data["names"]).to include("Pilot Iroshizuku Kon-peki")
      expect(parsed_data["names"]).to include("Pilot Iroshizuku Asa-gao")
      expect(parsed_data["names_as_elements"]).to be_present
    end

    it "includes colors when present" do
      # Mock the colors method to return specific colors before creating clusterer
      allow_any_instance_of(MicroCluster).to receive(:colors).and_return(%w[blue navy])
      clusterer = described_class.new(micro_cluster.id)
      data_message =
        clusterer.transcript.find { |msg| msg[:user] && msg[:user].include?("data for the ink") }[
          :user
        ]

      parsed_data = JSON.parse(data_message.split("This is the data for the ink to cluster: ").last)

      expect(parsed_data["colors"]).to eq(%w[blue navy])
    end

    it "excludes colors when not present" do
      # Mock colors to return empty array to simulate no colors
      allow_any_instance_of(MicroCluster).to receive(:colors).and_return([])
      clusterer = described_class.new(micro_cluster.id)
      data_message =
        clusterer.transcript.find { |msg| msg[:user] && msg[:user].include?("data for the ink") }[
          :user
        ]

      parsed_data = JSON.parse(data_message.split("This is the data for the ink to cluster: ").last)

      expect(parsed_data).not_to have_key("colors")
    end
  end

  describe "error handling" do
    context "when OpenAI API returns 500 error" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 500,
          body: "Internal Server Error"
        )
      end

      it "raises an error" do
        expect { subject.perform }.to raise_error(Faraday::ServerError)
      end
    end

    context "when OpenAI returns malformed JSON" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: "invalid json",
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises a parsing error" do
        expect { subject.perform }.to raise_error(Faraday::ParsingError)
      end
    end
  end

  describe "integration scenarios" do
    context "complete clustering workflow" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-integration",
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
                      "id" => "call_integration",
                      "type" => "function",
                      "function" => {
                        "name" => "assign_to_cluster",
                        "arguments" => {
                          "cluster_id" => existing_macro_cluster.id,
                          "explanation_of_decision" =>
                            "Both inks are Pilot Iroshizuku blues that belong in the same cluster."
                        }.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 300,
              "completion_tokens" => 50,
              "total_tokens" => 350
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "completes full clustering workflow" do
        subject.perform

        expect(subject.agent_log.extra_data["action"]).to eq("assign_to_cluster")
        expect(subject.agent_log.extra_data["cluster_id"]).to eq(existing_macro_cluster.id)
        expect(subject.agent_log.extra_data["explanation_of_decision"]).to include(
          "Pilot Iroshizuku"
        )
        expect(subject.agent_log.extra_data["follow_up_agent"]).to eq("CheckInkClustering::Assign")
        expect(subject.agent_log.state).to eq("waiting-for-approval")
        expect(RunInkClustererAgent.jobs.size).to eq(1)
        expect(RunInkClustererAgent.jobs.last["args"]).to eq(
          ["CheckInkClustering::Assign", subject.agent_log.id]
        )
      end
    end

    context "workflow with processed tries" do
      let!(:rejected_assign_log) do
        AgentLog.create!(
          name: "InkClusterer",
          owner: micro_cluster,
          transcript: [],
          state: "rejected",
          extra_data: {
            "action" => "assign_to_cluster",
            "cluster_id" => existing_macro_cluster.id
          },
          created_at: 2.hours.ago
        )
      end

      let!(:rejected_create_log) do
        AgentLog.create!(
          name: "InkClusterer",
          owner: micro_cluster,
          transcript: [],
          state: "rejected",
          extra_data: {
            "action" => "create_new_cluster"
          },
          created_at: 1.hour.ago
        )
      end

      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-retry",
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
                      "id" => "call_retry",
                      "type" => "function",
                      "function" => {
                        "name" => "ignore_ink",
                        "arguments" => {
                          "explanation_of_decision" =>
                            "After review, this appears to be a custom mix that should be ignored."
                        }.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 400,
              "completion_tokens" => 40,
              "total_tokens" => 440
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "includes information about previous rejected attempts" do
        subject.perform

        # Check that the transcript includes processed tries information
        processed_tries_message =
          subject
            .transcript
            .select { |msg| msg[:user] && msg[:user].include?("processed before") }
            .last[
            :user
          ]

        expect(processed_tries_message).to include("processed before 2 times")
        expect(processed_tries_message).to include("Assigning ink to existing cluster")
        expect(processed_tries_message).to include("Creating a new cluster")

        # Verify the final action is different from previous rejected ones
        expect(subject.agent_log.extra_data["action"]).to eq("ignore_ink")
        expect(subject.agent_log.extra_data["explanation_of_decision"]).to include("custom mix")
      end
    end

    context "with ink similarity search integration" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-search",
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
                      "id" => "call_search",
                      "type" => "function",
                      "function" => {
                        "name" => "assign_to_cluster",
                        "arguments" => {
                          "cluster_id" => existing_macro_cluster.id,
                          "explanation_of_decision" => "Test explanation"
                        }.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 100,
              "completion_tokens" => 50,
              "total_tokens" => 150
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "sends micro cluster data that can be used for similarity search" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            content = body["messages"].first["content"]

            # Should include system directive about clustering
            expect(content).to include("clustering algorithm")
            expect(content).to include("similar inks together")
            expect(content).to include("assign the ink to that cluster")
            expect(content).to include("create a new cluster")

            true
          }
          .at_least_once
      end

      it "includes instructions about web search capabilities" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            content = body["messages"].first["content"]

            expect(content).to include("search the web for it")
            expect(content).to include("help you termine if you should assign the ink")

            true
          }
          .at_least_once
      end
    end

    context "with brand validation" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-brand",
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
                      "id" => "call_brand",
                      "type" => "function",
                      "function" => {
                        "name" => "known_brand",
                        "arguments" => {}.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 200,
              "completion_tokens" => 20,
              "total_tokens" => 220
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "provides brand validation information to AI" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            if body["tools"].present?
              tool_names = body["tools"].map { |tool| tool["function"]["name"] }
              expect(tool_names).to include("known_brand")
            end
            true
          }
          .at_least_once
      end
    end
  end

  describe "transcript management" do
    context "with existing transcript" do
      let(:existing_transcript) do
        [
          { system: "Previous system message" },
          { user: "Previous user message" },
          { assistant: "Previous assistant response" }
        ]
      end

      it "uses existing transcript when available" do
        agent_log =
          AgentLog.create!(
            name: "InkClusterer",
            owner: micro_cluster,
            transcript: existing_transcript
          )

        clusterer = described_class.new(micro_cluster.id, agent_log_id: agent_log.id)

        expect(clusterer.transcript.to_a).to eq(existing_transcript)
      end
    end

    it "creates fresh transcript when none exists" do
      clusterer = described_class.new(micro_cluster.id)

      expect(clusterer.transcript.first[:system]).to include("clustering algorithm")
      expect(clusterer.transcript.find { |msg| msg[:user] }[:user]).to include(
        "data for the ink to cluster"
      )
    end
  end

  describe "edge cases" do
    context "with special characters in ink names" do
      let!(:special_ink) do
        create(
          :collected_ink,
          user: user,
          brand_name: 'Brand "With" Quotes',
          ink_name: "Ink, with commas & symbols"
        )
      end

      let!(:special_micro_cluster) do
        cluster = create(:micro_cluster)
        cluster.collected_inks = [special_ink]
        cluster
      end

      subject { described_class.new(special_micro_cluster.id) }

      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-special",
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
                      "id" => "call_special",
                      "type" => "function",
                      "function" => {
                        "name" => "assign_to_cluster",
                        "arguments" => {
                          "cluster_id" => existing_macro_cluster.id,
                          "explanation_of_decision" => "Test explanation"
                        }.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 100,
              "completion_tokens" => 50,
              "total_tokens" => 150
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles special characters in ink data" do
        subject.perform

        data_message =
          subject.transcript.find { |msg| msg[:user] && msg[:user].include?("data for the ink") }[
            :user
          ]
        parsed_data =
          JSON.parse(data_message.split("This is the data for the ink to cluster: ").last)

        expect(parsed_data["names"]).to include('Brand "With" Quotes Ink, with commas & symbols')
      end
    end

    context "with very long ink names" do
      let!(:long_name_ink) do
        create(:collected_ink, user: user, brand_name: "A" * 50, ink_name: "B" * 50)
      end

      let!(:long_name_cluster) do
        cluster = create(:micro_cluster)
        cluster.collected_inks = [long_name_ink]
        cluster
      end

      subject { described_class.new(long_name_cluster.id) }

      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-long",
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
                      "id" => "call_long",
                      "type" => "function",
                      "function" => {
                        "name" => "assign_to_cluster",
                        "arguments" => {
                          "cluster_id" => existing_macro_cluster.id,
                          "explanation_of_decision" => "Test explanation"
                        }.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 100,
              "completion_tokens" => 50,
              "total_tokens" => 150
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles very long ink names" do
        expect { subject.perform }.not_to raise_error

        data_message =
          subject.transcript.find { |msg| msg[:user] && msg[:user].include?("data for the ink") }[
            :user
          ]
        expect(data_message).to include("A" * 50)
        expect(data_message).to include("B" * 50)
      end
    end
  end

  describe "state management" do
    let(:assign_to_cluster_response) do
      {
        "id" => "chatcmpl-state",
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
                  "id" => "call_state",
                  "type" => "function",
                  "function" => {
                    "name" => "assign_to_cluster",
                    "arguments" => {
                      "cluster_id" => existing_macro_cluster.id,
                      "explanation_of_decision" => "Test explanation"
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 50,
          "total_tokens" => 150
        }
      }
    end

    it "tracks agent log state through workflow" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: assign_to_cluster_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      expect(subject.agent_log.state).to eq("processing")

      subject.perform

      expect(subject.agent_log.reload.state).to eq("waiting-for-approval")
    end

    it "maintains extra_data through approval process" do
      subject.agent_log.update!(
        extra_data: {
          "action" => "assign_to_cluster",
          "cluster_id" => existing_macro_cluster.id,
          "explanation_of_decision" => "Test explanation"
        }
      )

      subject.approve!

      expect(subject.agent_log.reload.extra_data["explanation_of_decision"]).to eq(
        "Test explanation"
      )
    end
  end
end
