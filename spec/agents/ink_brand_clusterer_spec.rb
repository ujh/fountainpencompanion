require "rails_helper"

RSpec.describe InkBrandClusterer do
  before(:each) { WebMock.reset! }

  let(:user) { create(:user) }
  let!(:macro_cluster) do
    create(:macro_cluster, brand_name: "Test Brand", line_name: "Test Line", ink_name: "Test Ink")
  end
  let!(:existing_brand_cluster) { create(:brand_cluster, name: "Existing Brand") }
  let!(:another_brand_cluster) { create(:brand_cluster, name: "Another Brand") }

  let!(:collected_ink) do
    create(:collected_ink, user: user, brand_name: "Test Brand", ink_name: "Test Ink")
  end
  let!(:micro_cluster) do
    cluster = create(:micro_cluster)
    cluster.collected_inks = [collected_ink]
    cluster.macro_cluster = macro_cluster
    cluster.save!
    cluster
  end

  let(:add_to_brand_cluster_response) do
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
                  "name" => "add_to_brand_cluster",
                  "arguments" => { "brand_cluster_id" => existing_brand_cluster.id }.to_json
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

  let(:create_new_brand_cluster_response) do
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
                  "name" => "create_new_brand_cluster",
                  "arguments" => {}.to_json
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

  subject { described_class.new(macro_cluster.id) }

  describe "#initialize" do
    it "creates agent with macro cluster" do
      clusterer = described_class.new(macro_cluster.id)
      expect(clusterer.agent_log.owner).to eq(macro_cluster)
      expect(clusterer.agent_log.name).to eq("InkBrandClusterer")
      expect(clusterer.agent_log).to be_persisted
    end
  end

  describe "#agent_log" do
    it "creates and memoizes agent log" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to be_persisted
      expect(log1.name).to eq("InkBrandClusterer")
      expect(log1.owner).to eq(macro_cluster)
      expect(log1).to eq(log2)
    end
  end

  describe "#perform" do
    context "when AI decides to add to existing brand cluster" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: add_to_brand_cluster_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "performs clustering and updates agent log" do
        expect { subject.perform }.to change { AgentLog.count }.by(1)

        agent_log = AgentLog.last
        expect(agent_log.name).to eq("InkBrandClusterer")
        expect(agent_log.state).to eq("waiting-for-approval")
        expect(agent_log.owner).to eq(macro_cluster)
        expect(agent_log.extra_data["action"]).to eq("add_to_brand_cluster")
        expect(agent_log.extra_data["brand_cluster_id"]).to eq(existing_brand_cluster.id)
      end

      it "uses correct OpenAI model" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions").with(
          body: hash_including(model: "gpt-4.1")
        ).at_least_once
      end

      it "includes tool definitions in the request" do
        subject.perform

        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).with { |req|
          body = JSON.parse(req.body)
          tools = body["tools"]
          tool_names = tools.map { |tool| tool["function"]["name"] }
          expect(tool_names).to include("add_to_brand_cluster")
          expect(tool_names).to include("create_new_brand_cluster")
          true
        }
      end

      it "assigns macro cluster to existing brand cluster" do
        subject.perform
        macro_cluster.reload
        expect(macro_cluster.brand_cluster).to eq(existing_brand_cluster)
      end
    end

    context "when AI decides to create new brand cluster" do
      let!(:unique_macro_cluster) do
        create(
          :macro_cluster,
          brand_name: "Unique Brand #{Time.current.to_i}",
          line_name: "Unique Line",
          ink_name: "Unique Ink"
        )
      end
      let!(:unique_collected_ink) do
        create(
          :collected_ink,
          user: user,
          brand_name: unique_macro_cluster.brand_name,
          ink_name: unique_macro_cluster.ink_name
        )
      end
      let!(:unique_micro_cluster) do
        cluster = create(:micro_cluster)
        cluster.collected_inks = [unique_collected_ink]
        cluster.macro_cluster = unique_macro_cluster
        cluster.save!
        cluster
      end

      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: create_new_brand_cluster_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "performs clustering and updates agent log" do
        clusterer = described_class.new(unique_macro_cluster.id)
        agent_log = clusterer.perform

        expect(agent_log.name).to eq("InkBrandClusterer")
        expect(agent_log.state).to eq("waiting-for-approval")
        expect(agent_log.owner).to eq(unique_macro_cluster)
        expect(agent_log.extra_data["action"]).to eq("create_new_brand_cluster")
      end

      it "creates new brand cluster and assigns macro cluster" do
        clusterer = described_class.new(unique_macro_cluster.id)
        initial_brand_cluster_count = BrandCluster.count

        clusterer.perform
        unique_macro_cluster.reload

        expect(BrandCluster.count).to eq(initial_brand_cluster_count + 1)
        expect(unique_macro_cluster.brand_cluster).to be_present
        expect(unique_macro_cluster.brand_cluster.name).to eq(unique_macro_cluster.brand_name)
      end
    end

    context "when OpenAI API returns error" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 500,
          body: { error: { message: "Internal server error" } }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises an error" do
        expect { subject.perform }.to raise_error(RubyLLM::ServerError)
      end
    end

    context "when OpenAI returns malformed JSON" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: "invalid json",
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises a parsing error" do
        expect { subject.perform }.to raise_error(RubyLLM::Error)
      end
    end
  end

  describe "data formatting" do
    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: add_to_brand_cluster_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "sends macro cluster data and brands data to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

          expect(content).to include("The ink in question has the following details:")
          expect(content).to include(macro_cluster.name)
          expect(content).to include("The following brands are already present in the system:")
          expect(content).to include(existing_brand_cluster.name)
          expect(content).to include(another_brand_cluster.name)

          true
        }
        .at_least_once
    end

    it "includes macro cluster data in valid JSON format" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

          json_str = content.match(/The ink in question has the following details: (.+?)$/m)[1]
          parsed_data = JSON.parse(json_str.split("\n").first)
          expect(parsed_data["name"]).to eq(macro_cluster.name)
          expect(parsed_data["name_details"]).to be_an(Array)

          true
        }
        .at_least_once
    end
  end

  describe "tools" do
    let(:tool_agent_log) { AgentLog.create!(name: "test", transcript: [], owner: macro_cluster) }

    describe InkBrandClusterer::AddToBrandCluster do
      it "has the correct description" do
        tool = described_class.new(macro_cluster, tool_agent_log)
        expect(tool.description).to eq("Add ink to the brand cluster")
      end

      it "has the correct name" do
        tool = described_class.new(macro_cluster, tool_agent_log)
        expect(tool.name).to eq("add_to_brand_cluster")
      end

      it "assigns to existing brand cluster and halts" do
        tool = described_class.new(macro_cluster, tool_agent_log)
        result = tool.call(brand_cluster_id: existing_brand_cluster.id)

        expect(result).to be_a(RubyLLM::Tool::Halt)
        expect(tool_agent_log.reload.extra_data["action"]).to eq("add_to_brand_cluster")
        expect(tool_agent_log.extra_data["brand_cluster_id"]).to eq(existing_brand_cluster.id)
        expect(macro_cluster.reload.brand_cluster).to eq(existing_brand_cluster)
      end

      it "returns error message for invalid brand_cluster_id" do
        tool = described_class.new(macro_cluster, tool_agent_log)
        result = tool.call(brand_cluster_id: 99_999)

        expect(result).to eq("This brand_cluster_id does not exist. Please try again.")
        expect(macro_cluster.reload.brand_cluster).to be_nil
      end
    end

    describe InkBrandClusterer::CreateNewBrandCluster do
      it "has the correct description" do
        tool = described_class.new(macro_cluster, tool_agent_log)
        expect(tool.description).to eq("Create a new brand cluster")
      end

      it "has the correct name" do
        tool = described_class.new(macro_cluster, tool_agent_log)
        expect(tool.name).to eq("create_new_brand_cluster")
      end

      it "creates new brand cluster and halts" do
        tool = described_class.new(macro_cluster, tool_agent_log)

        result = nil
        expect { result = tool.call }.to change { BrandCluster.count }.by(1)

        expect(result).to be_a(RubyLLM::Tool::Halt)
        expect(macro_cluster.reload.brand_cluster).to eq(BrandCluster.last)
        expect(tool_agent_log.reload.extra_data["action"]).to eq("create_new_brand_cluster")
      end
    end
  end

  describe "transcript restoration" do
    let(:existing_transcript) do
      [
        { "role" => "developer", "content" => "Your task is to determine..." },
        { "role" => "user", "content" => "The ink in question has the following details..." },
        {
          "role" => "assistant",
          "content" => "",
          "tool_calls" => [
            {
              "id" => "call_prev",
              "name" => "add_to_brand_cluster",
              "arguments" => {
                "brand_cluster_id" => existing_brand_cluster.id
              }
            }
          ]
        },
        {
          "role" => "tool",
          "content" => "Added to brand cluster Existing Brand",
          "tool_call_id" => "call_prev"
        }
      ]
    end

    let(:continued_response) do
      {
        "id" => "chatcmpl-continued",
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
                  "id" => "call_new",
                  "type" => "function",
                  "function" => {
                    "name" => "add_to_brand_cluster",
                    "arguments" => { "brand_cluster_id" => existing_brand_cluster.id }.to_json
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

    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: continued_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "restores messages including tool calls from an existing transcript" do
      agent_log =
        macro_cluster.agent_logs.create!(
          name: "InkBrandClusterer",
          state: "processing",
          transcript: existing_transcript
        )

      clusterer = described_class.new(macro_cluster.id)
      clusterer.instance_variable_set(:@agent_log, agent_log)

      clusterer.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        messages = body["messages"]

        user_restored =
          messages.find do |m|
            m["role"] == "user" &&
              m["content"]&.include?("The ink in question has the following details")
          end
        assistant_restored = messages.find { |m| m["role"] == "assistant" && m["tool_calls"]&.any? }
        tool_restored =
          messages.find { |m| m["role"] == "tool" && m["tool_call_id"] == "call_prev" }

        user_restored && assistant_restored && tool_restored &&
          assistant_restored["tool_calls"].first["id"] == "call_prev"
      }
    end
  end

  describe "transcript and usage tracking" do
    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: add_to_brand_cluster_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "updates agent log transcript" do
      subject.perform

      transcript = subject.agent_log.transcript
      expect(transcript).to be_an(Array)
      expect(transcript.length).to be >= 3
      expect(transcript.any? { |e| e["role"] == "user" }).to be true
      expect(transcript.any? { |e| e["role"] == "assistant" }).to be true
    end

    it "updates agent log usage" do
      subject.perform

      usage = subject.agent_log.usage
      expect(usage["prompt_tokens"]).to eq(300)
      expect(usage["completion_tokens"]).to eq(50)
      expect(usage["total_tokens"]).to eq(350)
      expect(usage["model"]).to eq("gpt-4.1")
    end
  end

  describe "edge cases" do
    context "when no existing brand clusters exist" do
      before do
        BrandCluster.destroy_all
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: create_new_brand_cluster_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles empty brand cluster list" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
            expect(content).to include("The following brands are already present in the system: []")
            true
          }
          .at_least_once
      end
    end

    context "with special characters in brand names" do
      let!(:special_macro_cluster) do
        create(
          :macro_cluster,
          brand_name: "J. Herbín",
          line_name: "Essentials",
          ink_name: "Violette Pensée"
        )
      end

      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: create_new_brand_cluster_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles special characters in brand data" do
        clusterer = described_class.new(special_macro_cluster.id)

        expect { clusterer.perform }.not_to raise_error

        agent_log = AgentLog.last
        expect(agent_log.extra_data["action"]).to eq("create_new_brand_cluster")
      end
    end
  end

  describe "integration scenarios" do
    context "complete brand clustering workflow" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: add_to_brand_cluster_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "completes full brand clustering workflow" do
        expect { subject.perform }.to change { AgentLog.count }.by(1)

        agent_log = AgentLog.last
        expect(agent_log.name).to eq("InkBrandClusterer")
        expect(agent_log.state).to eq("waiting-for-approval")
        expect(agent_log.owner).to eq(macro_cluster)
        expect(agent_log.extra_data["action"]).to eq("add_to_brand_cluster")
        expect(agent_log.extra_data["brand_cluster_id"]).to eq(existing_brand_cluster.id)

        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).at_least_once
      end
    end
  end
end
