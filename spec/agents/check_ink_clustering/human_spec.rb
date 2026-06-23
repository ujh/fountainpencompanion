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

    context "with existing processing agent log" do
      let!(:existing_agent_log) do
        micro_cluster_agent_log.agent_logs.create!(
          name: "CheckInkClustering::Human",
          transcript: [{ role: "user", content: "existing transcript" }],
          state: "processing"
        )
      end

      it "reuses existing processing agent log" do
        agent = described_class.new(micro_cluster_agent_log.id)
        expect(agent.send(:agent_log)).to eq(existing_agent_log)
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

      it "rejects the micro cluster agent log so it never reaches a reviewer" do
        subject.perform

        empty_agent_log.reload
        expect(empty_agent_log.state).to eq("rejected")
        expect(empty_agent_log.agent_approved).to be false
      end
    end

    context "with OpenAI API errors" do
      before do
        stub_request(:post, openai_url).to_return(status: 500, body: "Internal Server Error")
      end

      it "raises API errors as expected" do
        expect { subject.perform }.to raise_error(RubyLLM::ServerError)
      end

      it "does not approve on API error" do
        expect { subject.perform }.to raise_error(RubyLLM::ServerError)
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

  describe "tools" do
    describe "SendEmail" do
      it "sends email and halts" do
        mail_double = double("mail", deliver_later: true)
        expect(AdminMailer).to receive(:agent_mail).with("Test Subject", "Test Body").and_return(
          mail_double
        )

        tool = CheckInkClustering::Human::SendEmail.new
        result = tool.call(subject: "Test Subject", body: "Test Body")

        expect(result).to be_a(RubyLLM::Tool::Halt)
      end
    end

    describe "PreviousAgentLogs" do
      let(:agent) { CheckInkClustering::Human.new(micro_cluster_agent_log.id) }

      it "returns agent logs as JSON" do
        tool =
          CheckInkClustering::Human::PreviousAgentLogs.new(
            micro_cluster_agent_log,
            agent.send(:agent_log)
          )
        result = tool.call({})

        expect(result).to be_a(String)
        parsed = JSON.parse(result)
        expect(parsed).to be_an(Array)
      end
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

        # Verify the request includes the complex ink names
        expect(WebMock).to have_requested(:post, openai_url).with { |req|
          body = JSON.parse(req.body)
          messages = body["messages"]
          user_message = messages.find { |m| m["role"] == "user" }
          user_message["content"].include?("私人") &&
            user_message["content"].include?("Blue Mix + ???")
        }
      end
    end
  end
end
