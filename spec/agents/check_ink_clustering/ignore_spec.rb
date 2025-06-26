require "rails_helper"

RSpec.describe CheckInkClustering::Ignore do
  include ActiveSupport::Testing::TimeHelpers
  before(:each) { WebMock.reset! }

  let(:user) { create(:user) }
  let!(:collected_ink_1) do
    create(
      :collected_ink,
      user: user,
      brand_name: "Custom Mix",
      ink_name: "Pilot Blue + Diamine Red"
    )
  end
  let!(:collected_ink_2) do
    create(:collected_ink, user: user, brand_name: "Unknown", ink_name: "My Homemade Ink")
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
        { assistant: "This ink should be ignored as it's a custom mix" }
      ],
      state: "waiting-for-approval",
      extra_data: {
        "action" => "ignore_ink",
        "explanation_of_decision" =>
          "This ink is a custom mix and should be ignored from clustering."
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
      expect(child_log.name).to eq("CheckInkClustering::Ignore")
      expect(micro_cluster_agent_log.agent_logs).to include(child_log)
    end

    it "initializes transcript with system directive" do
      agent = described_class.new(micro_cluster_agent_log.id)
      expect(agent.transcript.first[:system]).to be_present
      expect(agent.transcript.first[:system]).to include(
        "reviewing the result of a clustering algorithm"
      )
      expect(agent.transcript.first[:system]).to include("ink should be ignored")
    end

    it "includes clustering explanation in transcript" do
      agent = described_class.new(micro_cluster_agent_log.id)
      explanation_message =
        agent.transcript.find { |msg| msg[:user]&.include?("reasoning of the AI") }
      expect(explanation_message).to be_present
      expect(explanation_message[:user]).to include("custom mix and should be ignored")
    end

    it "includes micro cluster data in transcript" do
      agent = described_class.new(micro_cluster_agent_log.id)
      cluster_data_message =
        agent.transcript.find { |msg| msg[:user]&.include?("data for the ink to cluster") }
      expect(cluster_data_message).to be_present
      expect(cluster_data_message[:user]).to include("Custom Mix")
      expect(cluster_data_message[:user]).to include("Pilot Blue + Diamine Red")
    end

    context "with existing agent log transcript" do
      let!(:existing_agent_log) do
        micro_cluster_agent_log.agent_logs.create!(
          name: "CheckInkClustering::Ignore",
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

    context "when approving ignoring" do
      let(:approve_response) do
        {
          "id" => "chatcmpl-ignore-123",
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
                    "id" => "call_approve_ignore",
                    "type" => "function",
                    "function" => {
                      "name" => "approve_cluster_creation",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "Ignoring is correct - this is clearly a custom ink mix."
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 280,
            "completion_tokens" => 40,
            "total_tokens" => 320
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
        expect(agent_log.extra_data["explanation_of_decision"]).to include("Ignoring is correct")
        expect(agent_log.state).to eq("waiting-for-approval")
      end

      it "updates micro cluster agent log with follow-up data" do
        subject.perform

        micro_cluster_agent_log.reload
        expect(micro_cluster_agent_log.extra_data["follow_up_done"]).to be true
        expect(micro_cluster_agent_log.extra_data["follow_up_action"]).to eq("approve")
        expect(micro_cluster_agent_log.extra_data["follow_up_action_explanation"]).to include(
          "Ignoring is correct"
        )
      end

      it "calls InkClusterer.approve! when approved" do
        expect_any_instance_of(InkClusterer).to receive(:approve!).with(agent: true)
        subject.perform
      end
    end

    context "when rejecting ignoring" do
      let(:reject_response) do
        {
          "id" => "chatcmpl-reject-ignore-123",
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
                    "id" => "call_reject_ignore",
                    "type" => "function",
                    "function" => {
                      "name" => "reject_cluster_creation",
                      "arguments" => {
                        "explanation_of_decision" =>
                          "Ignoring is incorrect - this is actually a legitimate ink that should be clustered."
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
        expect(agent_log.extra_data["explanation_of_decision"]).to include("Ignoring is incorrect")
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
            "action" => "ignore_ink",
            "explanation_of_decision" => "Ignore explanation"
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
    it "returns ignore review instructions" do
      directive = subject.send(:system_directive)
      expect(directive).to include("reviewing the result of a clustering algorithm")
      expect(directive).to include("ink should be ignored")
      expect(directive).to include("mix of inks")
      expect(directive).to include("unidentified ink")
      expect(directive).to include("someone created themselves")
      expect(directive).to include("incomplete entry")
      expect(directive).to include("not an ink")
      expect(directive).to include("separated by a non-word character")
      expect(directive).to include("known brand names")
      expect(directive).to include("search the web")
      expect(directive).to include("similarity search function")
      expect(directive).to include("Fewer results make it more likely")
      expect(directive).to include("More results make it more likely")
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
          "id" => "chatcmpl-ignore-integration-123",
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
                    "id" => "call_approve_ignore_integration",
                    "type" => "function",
                    "function" => {
                      "name" => "approve_cluster_creation",
                      "arguments" => {
                        "explanation_of_decision" => "Integration test approval for ignoring ink"
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
          "id" => "chatcmpl-reject-ignore-integration-123",
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
                    "id" => "call_reject_ignore_integration",
                    "type" => "function",
                    "function" => {
                      "name" => "reject_cluster_creation",
                      "arguments" => {
                        "explanation_of_decision" => "Integration test rejection for ignoring ink"
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

    context "with various ignorable ink types" do
      context "ink mixes" do
        let!(:mix_ink) do
          create(
            :collected_ink,
            user: user,
            brand_name: "Custom",
            ink_name: "Waterman Blue + Parker Black"
          )
        end

        let!(:mix_micro_cluster) do
          cluster = create(:micro_cluster)
          cluster.collected_inks = [mix_ink]
          cluster
        end

        let!(:mix_agent_log) do
          AgentLog.create!(
            name: "InkClusterer",
            owner: mix_micro_cluster,
            transcript: [],
            state: "waiting-for-approval",
            extra_data: {
              "action" => "ignore_ink",
              "explanation_of_decision" => "This is a mix of two inks"
            }
          )
        end

        subject { described_class.new(mix_agent_log.id) }

        let(:approve_mix_response) do
          {
            "id" => "chatcmpl-mix-123",
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
                      "id" => "call_approve_mix",
                      "type" => "function",
                      "function" => {
                        "name" => "approve_cluster_creation",
                        "arguments" => {
                          "explanation_of_decision" =>
                            "Correct - this is clearly a mix of two different inks."
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
            body: approve_mix_response.to_json,
            headers: {
              "Content-Type" => "application/json"
            }
          )
        end

        it "correctly handles ink mixes" do
          subject.perform

          agent_log = subject.send(:agent_log)
          expect(agent_log.extra_data["action"]).to eq("approve")
          expect(agent_log.extra_data["explanation_of_decision"]).to include(
            "mix of two different inks"
          )

          # Verify the ink name appears in transcript
          cluster_data_message =
            subject.transcript.find { |msg| msg[:user]&.include?("data for the ink to cluster") }
          expect(cluster_data_message[:user]).to include("Waterman Blue + Parker Black")
        end
      end

      context "incomplete entries" do
        let!(:incomplete_ink) do
          create(:collected_ink, user: user, brand_name: "Pilot", ink_name: "Blue")
        end

        let!(:incomplete_micro_cluster) do
          cluster = create(:micro_cluster)
          cluster.collected_inks = [incomplete_ink]
          cluster
        end

        let!(:incomplete_agent_log) do
          AgentLog.create!(
            name: "InkClusterer",
            owner: incomplete_micro_cluster,
            transcript: [],
            state: "waiting-for-approval",
            extra_data: {
              "action" => "ignore_ink",
              "explanation_of_decision" => "Too generic, not a full ink name"
            }
          )
        end

        subject { described_class.new(incomplete_agent_log.id) }

        let(:approve_incomplete_response) do
          {
            "id" => "chatcmpl-incomplete-123",
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
                      "id" => "call_approve_incomplete",
                      "type" => "function",
                      "function" => {
                        "name" => "approve_cluster_creation",
                        "arguments" => {
                          "explanation_of_decision" =>
                            "Correct - 'Blue' is too generic and incomplete."
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
            body: approve_incomplete_response.to_json,
            headers: {
              "Content-Type" => "application/json"
            }
          )
        end

        it "correctly handles incomplete entries" do
          subject.perform

          agent_log = subject.send(:agent_log)
          expect(agent_log.extra_data["action"]).to eq("approve")
          expect(agent_log.extra_data["explanation_of_decision"]).to include(
            "too generic and incomplete"
          )
        end
      end

      context "non-ink products" do
        let!(:ballpoint_ink) do
          create(:collected_ink, user: user, brand_name: "Bic", ink_name: "Ballpoint Pen Blue")
        end

        let!(:ballpoint_micro_cluster) do
          cluster = create(:micro_cluster)
          cluster.collected_inks = [ballpoint_ink]
          cluster
        end

        let!(:ballpoint_agent_log) do
          AgentLog.create!(
            name: "InkClusterer",
            owner: ballpoint_micro_cluster,
            transcript: [],
            state: "waiting-for-approval",
            extra_data: {
              "action" => "ignore_ink",
              "explanation_of_decision" => "This is not a fountain pen ink, it's a ballpoint pen"
            }
          )
        end

        subject { described_class.new(ballpoint_agent_log.id) }

        let(:approve_ballpoint_response) do
          {
            "id" => "chatcmpl-ballpoint-123",
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
                      "id" => "call_approve_ballpoint",
                      "type" => "function",
                      "function" => {
                        "name" => "approve_cluster_creation",
                        "arguments" => {
                          "explanation_of_decision" =>
                            "Correct - this is a ballpoint pen, not fountain pen ink."
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
            body: approve_ballpoint_response.to_json,
            headers: {
              "Content-Type" => "application/json"
            }
          )
        end

        it "correctly handles non-ink products" do
          subject.perform

          agent_log = subject.send(:agent_log)
          expect(agent_log.extra_data["action"]).to eq("approve")
          expect(agent_log.extra_data["explanation_of_decision"]).to include(
            "ballpoint pen, not fountain pen ink"
          )
        end
      end
    end
  end
end
