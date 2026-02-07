require "rails_helper"

describe SaveCollectedInk do
  let(:collected_ink) do
    create(:collected_ink, brand_name: "Pilot", line_name: "Iroshizuku", ink_name: "Kon-Peki")
  end

  it "schedules a AssignMicroCluster job" do
    expect do described_class.new(collected_ink, {}).perform end.to change {
      AssignMicroCluster.jobs.size
    }.by(1)
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

  describe "archived parameter handling" do
    it "ignores archived parameter when true" do
      expect(collected_ink.archived_on).to be_nil

      described_class.new(collected_ink, { archived: true }).perform

      expect(collected_ink.reload.archived_on).to be_nil
    end

    it "ignores archived parameter when false" do
      original_date = Date.current
      collected_ink.update!(archived_on: original_date)

      described_class.new(collected_ink, { archived: false }).perform

      expect(collected_ink.reload.archived_on).to eq(original_date)
    end

    it "ignores string keys for archived parameter" do
      described_class.new(collected_ink, { "archived" => true }).perform

      expect(collected_ink.reload.archived_on).to be_nil
    end
  end
end
