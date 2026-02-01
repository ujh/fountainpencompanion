require "rails_helper"

describe FetchEmbedding do
  it "fetches the embedding" do
    vector = Array.new(1536, 0.0)
    embedding = create(:pen_embedding, owner: create(:collected_pen), content: "content")

    # Stub Ollama endpoint for development
    ollama_stub =
      stub_request(:post, "http://ollama:11434/api/embeddings").with(
        body: { model: "nomic-embed-text", prompt: "content" }.to_json
      ).to_return(
        status: 200,
        headers: {
          "Content-Type" => "application/json"
        },
        body: { embedding: Array.new(768, 0.0) }.to_json
      )

    # Stub OpenAI endpoint for production
    openai_stub =
      stub_request(:post, "https://api.openai.com/v1/embeddings").with(
        body: { model: "text-embedding-3-small", input: "content" }.to_json
      ).to_return(
        status: 200,
        headers: {
          "Content-Type" => "application/json"
        },
        body: { data: [{ embedding: vector }] }.to_json
      )

    FetchEmbedding.drain

    if ENV["USE_OLLAMA"] == "true"
      expect(ollama_stub).to have_been_requested
    else
      expect(openai_stub).to have_been_requested
    end

    expect(embedding.reload.embedding).to eq(vector)
  end
end
