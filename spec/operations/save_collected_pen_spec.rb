require "rails_helper"

describe SaveCollectedPen do
  let(:collected_pen) { create(:collected_pen) }

  it "adds the embedding if there is none" do
    expect do described_class.new(collected_pen, {}).perform end.to change {
      PenEmbedding.count
    }.by(1)
  end

  it "properly updates the embedding content" do
    described_class.new(collected_pen, {}).perform
    embedding = collected_pen.pen_embedding
    expect(embedding.content).to eq(collected_pen.model_name)
  end

  it "updates the embedding if it already exists" do
    embedding =
      create(:pen_embedding, owner: collected_pen, content: "old content")
    expect do
      expect { described_class.new(collected_pen, {}).perform }.not_to(
        change { PenEmbedding.count }
      )
    end.to change { embedding.reload.content }.from("old content").to(
      collected_pen.model_name
    )
  end

  it "does not add an embedding if update failed" do
    expect { described_class.new(collected_pen, { model: "" }).perform }.not_to(
      change { PenEmbedding.count }
    )
  end
end
