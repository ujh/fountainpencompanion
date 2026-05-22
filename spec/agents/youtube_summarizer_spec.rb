require "rails_helper"

RSpec.describe YoutubeSummarizer do
  let(:user) { create(:user) }
  let(:parent_agent_log) do
    AgentLog.create!(name: "ParentAgent", owner: user, state: "processing", transcript: [])
  end

  let(:macro_cluster) { create(:macro_cluster) }
  let(:youtube_channel) { create(:you_tube_channel, channel_id: "UC123") }
  let(:source) do
    create(
      :ink_review,
      title: "Pilot Tsuki-yo Review",
      description: "Today we review Tsuki-yo",
      image: "https://img.youtube.com/vi/abc/maxresdefault.jpg",
      url: "https://www.youtube.com/watch?v=abc",
      you_tube_channel: youtube_channel,
      macro_cluster: macro_cluster,
      youtube_tags: %w[ink review],
      youtube_comments: [{ author: "Alice", text: "Stunning ink", like_count: 9 }],
      youtube_captions: "Pilot Iroshizuku Tsuki-yo is a dark blue ink with sheen."
    )
  end

  let(:summary_response) do
    {
      "id" => "chatcmpl-yt",
      "object" => "chat.completion",
      "created" => 1_677_652_288,
      "model" => "gpt-4.1-mini",
      "choices" => [
        {
          "index" => 0,
          "message" => {
            "role" => "assistant",
            "content" => "The video is a focused review of Pilot Iroshizuku Tsuki-yo."
          },
          "finish_reason" => "stop"
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
      body: summary_response.to_json,
      headers: {
        "Content-Type" => "application/json"
      }
    )
  end

  subject { described_class.new(parent_agent_log, source) }

  it "creates an agent log under the parent" do
    subject.perform
    log = subject.agent_log
    expect(log.owner).to eq(parent_agent_log)
    expect(log.name).to eq("YoutubeSummarizer")
    expect(log.reload.state).to eq("waiting-for-approval")
  end

  it "returns the LLM summary text" do
    expect(subject.perform).to eq("The video is a focused review of Pilot Iroshizuku Tsuki-yo.")
  end

  it "sends title, description, tags, comments, and captions in the user prompt" do
    subject.perform

    expect(WebMock).to have_requested(
      :post,
      "https://api.openai.com/v1/chat/completions"
    ).with { |req|
      body = JSON.parse(req.body)
      user_msg = body["messages"].find { |m| m["role"] == "user" }
      content = user_msg["content"]
      text = content.is_a?(Array) ? content.find { |p| p["type"] == "text" }&.[]("text") : content

      text.include?("Pilot Tsuki-yo Review") && text.include?("Today we review Tsuki-yo") &&
        text.include?("ink, review") && text.include?("Alice") && text.include?("Stunning ink") &&
        text.include?("dark blue ink with sheen")
    }
  end

  it "attaches the thumbnail as an image_url part" do
    subject.perform

    expect(WebMock).to have_requested(
      :post,
      "https://api.openai.com/v1/chat/completions"
    ).with { |req|
      body = JSON.parse(req.body)
      user_msg = body["messages"].find { |m| m["role"] == "user" }
      parts = user_msg["content"]
      parts.is_a?(Array) &&
        parts.any? { |p| p["type"] == "image_url" && p["image_url"]["url"] == source.image }
    }
  end

  it "renders captions placeholder when none are present" do
    source.update_column(:youtube_captions, nil)

    subject.perform

    expect(WebMock).to have_requested(
      :post,
      "https://api.openai.com/v1/chat/completions"
    ).with { |req|
      body = JSON.parse(req.body)
      user_msg = body["messages"].find { |m| m["role"] == "user" }
      content = user_msg["content"]
      text = content.is_a?(Array) ? content.find { |p| p["type"] == "text" }&.[]("text") : content
      text.include?("(none available)")
    }
  end

  it "accepts an Unfurler::Result duck-typed source" do
    unfurler_source =
      Unfurler::Result.new(
        "https://www.youtube.com/watch?v=xyz",
        "Yet Another Review",
        "Description",
        "https://img.youtube.com/vi/xyz/maxresdefault.jpg",
        "Channel",
        "UC456",
        false,
        nil,
        { tags: %w[a b], comments: [{ author: "Z", text: "hi", like_count: 0 }], captions: "C." }
      )

    result = described_class.new(parent_agent_log, unfurler_source).perform

    expect(result).to be_a(String)
    expect(WebMock).to have_requested(
      :post,
      "https://api.openai.com/v1/chat/completions"
    ).with { |req|
      body = JSON.parse(req.body)
      user_msg = body["messages"].find { |m| m["role"] == "user" }
      content = user_msg["content"]
      text = content.is_a?(Array) ? content.find { |p| p["type"] == "text" }&.[]("text") : content
      text.include?("Yet Another Review") && text.include?("a, b") && text.include?("C.")
    }
  end
end
