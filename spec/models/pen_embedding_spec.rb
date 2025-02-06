require "rails_helper"

RSpec.describe PenEmbedding do
  let(:owner) { create(:collected_pen) }

  it "fetches the embedding when creating the model" do
    expect do described_class.create!(content: "content", owner: owner) end.to change {
      FetchEmbedding.jobs.count
    }.by(1)
  end

  it "fetches the embedding when content has changed" do
    embedding = described_class.create!(content: "content", owner: owner)
    expect do embedding.update!(content: "new content") end.to change {
      FetchEmbedding.jobs.count
    }.by(1)
  end

  it "does not fetch the embedding when model has not changed" do
    embedding = described_class.create!(content: "content", owner: owner)

    expect { embedding.update!(owner: create(:collected_pen)) }.not_to(
      change { FetchEmbedding.jobs.count }
    )
  end
end
