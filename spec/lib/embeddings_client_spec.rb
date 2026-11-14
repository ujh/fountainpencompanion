require "rails_helper"

RSpec.describe EmbeddingsClient do
  it "identifies the app to OpenAI" do
    stub =
      stub_request(:post, "https://api.openai.com/v1/embeddings").with(
        headers: {
          "User-Agent" => Fountainpencompanion::USER_AGENT
        }
      ).to_return(
        status: 200,
        body: {
          object: "list",
          data: [{ object: "embedding", index: 0, embedding: [0.1, 0.2] }],
          model: "text-embedding-3-small",
          usage: {
            prompt_tokens: 2,
            total_tokens: 2
          }
        }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

    expect(described_class.new.fetch("user agent spec")).to eq([0.1, 0.2])
    expect(stub).to have_been_requested
  end
end
