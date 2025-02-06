require "rails_helper"

describe FetchEmbedding do
  it "fetches the embedding" do
    vector = Array.new(1536, 0.0)
    embedding =
      create(:pen_embedding, owner: create(:collected_pen), content: "content")
    stub =
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
    expect(stub).to have_been_requested
    expect(embedding.reload.embedding).to eq(vector)
  end
end
