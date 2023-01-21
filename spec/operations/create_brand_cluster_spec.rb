require 'rails_helper'

describe CreateBrandCluster do
  let(:macro_cluster) { create(:macro_cluster) }

  it 'creates a brand cluster' do
    expect do
      described_class.new(macro_cluster).perform
    end.to change(BrandCluster, :count).by(1)
  end

  it 'assigns the macro cluster to the brand cluster' do
    brand_cluster = described_class.new(macro_cluster).perform
    expect(macro_cluster.reload.brand_cluster).to eq(brand_cluster)
  end

  it 'creates a brand cluster with the name of the macro cluster' do
    brand_cluster = described_class.new(macro_cluster).perform
    expect(brand_cluster.name).to eq(macro_cluster.brand_name)
  end

  it 'assigns all macro clusters with the same brand name to the new brand cluster' do
    second_macro_cluster = create(:macro_cluster, brand_name: macro_cluster.brand_name)
    brand_cluster = described_class.new(macro_cluster).perform
    expect(second_macro_cluster.reload.brand_cluster).to eq(brand_cluster)
  end

  it 'does not assign other macro clusters with a different brand name' do
    second_macro_cluster = create(:macro_cluster, brand_name: 'other brand name')
    brand_cluster = described_class.new(macro_cluster).perform
    expect(second_macro_cluster.reload.brand_cluster).not_to eq(brand_cluster)
  end
end
