require "rails_helper"

describe SaveCollectedInk do
  let(:collected_ink) do
    create(:collected_ink, brand_name: "Pilot", line_name: "Iroshizuku", ink_name: "Kon-Peki")
  end

  it "schedules a AssignMicroCluster job" do
    expect do described_class.new(collected_ink, {}).perform end.to change {
      AssignMicroCluster.jobs.size
    }.by(1)
    expect(AssignMicroCluster.jobs.last["args"]).to eq([collected_ink.id, nil])
  end

  it "passes macro_cluster_id to AssignMicroCluster" do
    macro_cluster = create(:macro_cluster)
    expect do
      described_class.new(collected_ink, {}, macro_cluster_id: macro_cluster.id).perform
    end.to change { AssignMicroCluster.jobs.size }.by(1)
    expect(AssignMicroCluster.jobs.last["args"]).to eq([collected_ink.id, macro_cluster.id])
  end

  it "adds the embedding" do
    expect do described_class.new(collected_ink, {}).perform end.to change {
      InkEmbedding.count
    }.by(1)
    embedding = InkEmbedding.first
    expect(embedding.content).to eq("Pilot Iroshizuku Kon-Peki")
  end

  it "updates an existing embedding" do
    embedding = collected_ink.create_ink_embedding(content: "wrong")

    expect do
      expect do described_class.new(collected_ink, {}).perform end.to change {
        embedding.reload.content
      }.from("wrong").to("Pilot Iroshizuku Kon-Peki")
    end.not_to(change { InkEmbedding.count })
  end
end
