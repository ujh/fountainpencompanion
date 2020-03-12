require 'rails_helper'

describe AssignMicroCluster do
  let(:collected_ink) { create(:collected_ink) }

  it 'creates a new cluster and assigns it if no matching one exists' do
    expect do
      subject.perform(collected_ink.id)
    end.to change { MicroCluster.count }.by(1)
    expect(collected_ink.reload.micro_cluster).to eq(MicroCluster.last)
  end

  it 'reuses an existing cluster' do
    cluster = create(
      :micro_cluster,
      simplified_brand_name: collected_ink.simplified_brand_name,
      simplified_line_name: collected_ink.simplified_line_name,
      simplified_ink_name: collected_ink.simplified_ink_name
    )
    expect do
      subject.perform(collected_ink.id)
    end.to_not change { MicroCluster.count }
    expect(collected_ink.reload.micro_cluster).to eq(cluster)
  end
end
