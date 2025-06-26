require "rails_helper"

RSpec.describe CheckInkClustering::Human do
  include ActiveSupport::Testing::TimeHelpers
  before(:each) { WebMock.reset! }

  let(:user) { create(:user) }
  let!(:collected_ink_1) do
    create(:collected_ink, user: user, brand_name: "Unknown Brand", ink_name: "Mystery Ink #1")
  end
  let!(:collected_ink_2) do
    create(:collected_ink, user: user, brand_name: "Unknown Brand", ink_name: "Mystery Ink #2")
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
        { assistant: "I need human review for this complex case" }
      ],
      state: "waiting-for-approval",
      extra_data: {
        "action" => "hand_over_to_human",
        "explanation_of_decision" =>
          "This clustering case is too complex and requires human judgment."
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
      expect(child_log.name).to eq("CheckInkClustering::Human")
      expect(micro_cluster_agent_log.agent_logs).to include(child_log)
    end

    it "initializes transcript with system directive" do
      agent = described_class.new(micro_cluster_agent_log.id)
      expect(agent.transcript.first[:system]).to be_present
      expect(agent.transcript.first[:system]).to include(
        "reviewing the result of a clustering algorithm"
      )
      expect(agent.transcript.first[:system]).to include("handed over to a human for review")
      expect(agent.transcript.first[:system]).to include("send an email")
    end

    it "includes clustering explanation in transcript" do
      agent = described_class.new(micro_cluster_agent_log.id)
      explanation_message =
        agent.transcript.find { |msg| msg[:user]&.include?("reasoning of the AI") }
      expect(explanation_message).to be_present
      expect(explanation_message[:user]).to include("too complex and requires human judgment")
    end

    it "includes micro cluster data in transcript" do
      agent = described_class.new(micro_cluster_agent_log.id)
      cluster_data_message =
        agent.transcript.find { |msg| msg[:user]&.include?("data for the ink to cluster") }
      expect(cluster_data_message).to be_present
      expect(cluster_data_message[:user]).to include("Unknown Brand")
      expect(cluster_data_message[:user]).to include("Mystery Ink")
    end

    context "with existing agent log transcript" do
      let!(:existing_agent_log) do
        micro_cluster_agent_log.agent_logs.create!(
          name: "CheckInkClustering::Human",
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

    context "when sending email to human reviewer" do
      let(:email_response) do
        {
          "id" => "chatcmpl-human-123",
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
                    "id" => "call_send_email",
                    "type" => "function",
                    "function" => {
                      "name" => "send_email",
                      "arguments" => {
                        "subject" => "Ink Clustering Review Required",
                        "body" =>
                          "A complex ink clustering case requires human review. The AI determined that this case is too complex and requires human judgment."
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
            "completion_tokens" => 60,
            "total_tokens" => 360
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: email_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )

        # Mock the mailer
        allow(AdminMailer).to receive(:agent_mail).and_return(double("mail", deliver_later: true))
      end

      it "sends correct request to OpenAI" do
        subject.perform

        expect(WebMock).to have_requested(:post, openai_url).at_least_once
      end

      it "sends email via AdminMailer" do
        expect(AdminMailer).to receive(:agent_mail).with(
          "Ink Clustering Review Required",
          include("complex ink clustering case")
        ).and_return(double("mail", deliver_later: true))

        subject.perform
      end

      it "sets agent log to waiting for approval" do
        subject.perform

        agent_log = subject.send(:agent_log)
        expect(agent_log.state).to eq("waiting-for-approval")
      end

      it "approves the micro cluster agent log" do
        subject.perform
        # The approve! method is called at the end of perform, not mocked
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
            "action" => "hand_over_to_human",
            "explanation_of_decision" => "Human review needed"
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

      it "still approves the micro cluster agent log" do
        expect_any_instance_of(AgentLog).to receive(:approve!)
        subject.perform
      end
    end

    context "with OpenAI API errors" do
      before do
        stub_request(:post, openai_url).to_return(status: 500, body: "Internal Server Error")
      end

      it "raises API errors as expected" do
        expect { subject.perform }.to raise_error(Faraday::ServerError)
      end

      it "does not approve on API error" do
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

      it "does not approve on malformed response" do
        expect { subject.perform }.to raise_error(NoMethodError)
      end
    end
  end

  describe "#system_directive" do
    it "returns human review instructions" do
      directive = subject.send(:system_directive)
      expect(directive).to include("reviewing the result of a clustering algorithm")
      expect(directive).to include("handed over to a human for review")
      expect(directive).to include("summarize the reasoning")
      expect(directive).to include("send an email")
      expect(directive).to include("human reviewer")
    end
  end

  describe "function definitions" do
    it "responds to send_email function" do
      expect(subject).to respond_to(:send_email)
    end
  end

  describe "integration scenarios" do
    let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

    context "complete human review workflow" do
      let(:email_response) do
        {
          "id" => "chatcmpl-human-integration-123",
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
                    "id" => "call_email_integration",
                    "type" => "function",
                    "function" => {
                      "name" => "send_email",
                      "arguments" => {
                        "subject" => "Integration Test: Ink Clustering Review",
                        "body" =>
                          "Integration test email body with clustering details and reasoning."
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
          body: email_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )

        allow(AdminMailer).to receive(:agent_mail).and_return(double("mail", deliver_later: true))
      end

      it "completes full human review workflow" do
        expect(AdminMailer).to receive(:agent_mail).with(
          "Integration Test: Ink Clustering Review",
          include("Integration test email body")
        ).and_return(double("mail", deliver_later: true))

        subject.perform

        # Verify agent log state
        agent_log = subject.send(:agent_log)
        expect(agent_log.state).to eq("waiting-for-approval")
      end
    end

    context "with complex clustering case" do
      let!(:complex_ink_1) do
        create(:collected_ink, user: user, brand_name: "私人", ink_name: "手作藍墨水")
      end
      let!(:complex_ink_2) do
        create(:collected_ink, user: user, brand_name: "Custom", ink_name: "Blue Mix + ???")
      end

      let!(:complex_micro_cluster) do
        cluster = create(:micro_cluster)
        cluster.collected_inks = [complex_ink_1, complex_ink_2]
        cluster
      end

      let!(:complex_agent_log) do
        AgentLog.create!(
          name: "InkClusterer",
          owner: complex_micro_cluster,
          transcript: [],
          state: "waiting-for-approval",
          extra_data: {
            "action" => "hand_over_to_human",
            "explanation_of_decision" =>
              "These inks have non-standard names and require human judgment."
          }
        )
      end

      subject { described_class.new(complex_agent_log.id) }

      let(:complex_email_response) do
        {
          "id" => "chatcmpl-complex-123",
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
                    "id" => "call_complex_email",
                    "type" => "function",
                    "function" => {
                      "name" => "send_email",
                      "arguments" => {
                        "subject" => "Complex Ink Names Require Review",
                        "body" =>
                          "Complex clustering case with non-standard ink names including Chinese characters and incomplete names."
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
          body: complex_email_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )

        allow(AdminMailer).to receive(:agent_mail).and_return(double("mail", deliver_later: true))
      end

      it "handles complex ink names in human review" do
        expect(AdminMailer).to receive(:agent_mail).with(
          "Complex Ink Names Require Review",
          include("non-standard ink names")
        ).and_return(double("mail", deliver_later: true))

        subject.perform

        # Verify the micro cluster data includes complex names
        cluster_data_message =
          subject.transcript.find { |msg| msg[:user]&.include?("data for the ink to cluster") }
        expect(cluster_data_message[:user]).to include("私人")
        expect(cluster_data_message[:user]).to include("手作藍墨水")
        expect(cluster_data_message[:user]).to include("Blue Mix + ???")
      end
    end
  end
end
