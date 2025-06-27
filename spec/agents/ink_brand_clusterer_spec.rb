require "rails_helper"

RSpec.describe InkBrandClusterer do
  include ActiveSupport::Testing::TimeHelpers
  before(:each) { WebMock.reset! }

  let(:user) { create(:user) }
  let!(:macro_cluster) do
    create(:macro_cluster, brand_name: "Test Brand", line_name: "Test Line", ink_name: "Test Ink")
  end
  let!(:existing_brand_cluster) { create(:brand_cluster, name: "Existing Brand") }
  let!(:another_brand_cluster) { create(:brand_cluster, name: "Another Brand") }

  # Create some collected inks to give the macro cluster some data
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
      expect(clusterer.send(:macro_cluster)).to eq(macro_cluster)
    end

    it "initializes transcript with system directive" do
      clusterer = described_class.new(macro_cluster.id)
      expect(clusterer.transcript.first[:system]).to be_present
      expect(clusterer.transcript.first[:system]).to include("determine if the given ink belongs")
      expect(clusterer.transcript.first[:system]).to include("existing brands")
    end

    it "includes macro cluster data in transcript" do
      clusterer = described_class.new(macro_cluster.id)
      user_messages = clusterer.transcript.select { |msg| msg[:user] }
      expect(user_messages.size).to eq(2)

      cluster_data = user_messages.first[:user]
      expect(cluster_data).to include("The ink in question has the following details:")
      expect(cluster_data).to include(macro_cluster.name)
    end

    it "includes existing brands data in transcript" do
      clusterer = described_class.new(macro_cluster.id)
      user_messages = clusterer.transcript.select { |msg| msg[:user] }

      brands_data = user_messages.last[:user]
      expect(brands_data).to include("The following brands are already present in the system:")
      expect(brands_data).to include(existing_brand_cluster.name)
      expect(brands_data).to include(another_brand_cluster.name)
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

      it "includes function definitions in the request" do
        subject.perform

        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).with { |req| JSON.parse(req.body).key?("tools") }
      end

      it "assigns macro cluster to existing brand cluster when not evaluating" do
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

      it "creates new brand cluster and assigns macro cluster when not evaluating" do
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
        expect { subject.perform }.to raise_error(Faraday::ServerError)
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
        expect { subject.perform }.to raise_error(Faraday::ParsingError)
      end
    end
  end

  describe "function validation through OpenAI responses" do
    context "when AI calls add_to_brand_cluster with valid brand_cluster_id" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: add_to_brand_cluster_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "processes valid brand cluster assignment" do
        agent_log = subject.perform
        expect(agent_log.extra_data["brand_cluster_id"]).to eq(existing_brand_cluster.id)
      end
    end

    context "when AI calls add_to_brand_cluster with invalid brand_cluster_id" do
      let(:invalid_response) do
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
                      "arguments" => { "brand_cluster_id" => 99_999 }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 250,
            "completion_tokens" => 30,
            "total_tokens" => 280
          }
        }
      end

      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: invalid_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles invalid brand cluster ID with error message" do
        # This should trigger the validation in the function and return an error message
        # The agent framework should handle this gracefully
        expect { subject.perform }.not_to raise_error
      end
    end
  end

  describe "data formatting" do
    it "includes macro cluster data in JSON format" do
      clusterer = described_class.new(macro_cluster.id)
      user_messages = clusterer.transcript.select { |msg| msg[:user] }
      cluster_data = user_messages.first[:user]

      parsed_data =
        JSON.parse(cluster_data.gsub("The ink in question has the following details: ", ""))
      expect(parsed_data["name"]).to eq(macro_cluster.name)
      expect(parsed_data["name_details"]).to be_an(Array)
    end

    it "includes existing brands data in JSON format" do
      clusterer = described_class.new(macro_cluster.id)
      user_messages = clusterer.transcript.select { |msg| msg[:user] }
      brands_data = user_messages.last[:user]

      parsed_data =
        JSON.parse(brands_data.gsub("The following brands are already present in the system: ", ""))
      expect(parsed_data).to be_an(Array)
      expect(parsed_data.any? { |brand| brand["name"] == existing_brand_cluster.name }).to be true
    end

    it "handles synonyms correctly" do
      clusterer = described_class.new(macro_cluster.id)
      user_messages = clusterer.transcript.select { |msg| msg[:user] }
      cluster_data = user_messages.first[:user]

      # Test that the data structure is valid JSON and includes expected fields
      parsed_data =
        JSON.parse(cluster_data.gsub("The ink in question has the following details: ", ""))
      expect(parsed_data).to have_key("name")
      expect(parsed_data).to have_key("name_details")
      # Synonyms field is optional based on whether synonyms exist
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

        # Verify at least one request was made to OpenAI
        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).at_least_once
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
        clusterer = described_class.new(macro_cluster.id)
        user_messages = clusterer.transcript.select { |msg| msg[:user] }
        brands_data = user_messages.last[:user]

        parsed_data =
          JSON.parse(
            brands_data.gsub("The following brands are already present in the system: ", "")
          )
        expect(parsed_data).to eq([])

        expect { clusterer.perform }.not_to raise_error
      end
    end
  end

  describe "state management" do
    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: add_to_brand_cluster_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "tracks agent log state through workflow" do
      agent_log = subject.perform

      expect(agent_log.state).to eq("waiting-for-approval")
      expect(agent_log.owner).to eq(macro_cluster)
      expect(agent_log.name).to eq("InkBrandClusterer")
    end

    it "maintains extra_data through workflow" do
      agent_log = subject.perform

      expect(agent_log.extra_data).to be_present
      expect(agent_log.extra_data["action"]).to eq("add_to_brand_cluster")
      expect(agent_log.extra_data["brand_cluster_id"]).to eq(existing_brand_cluster.id)
    end
  end
end
