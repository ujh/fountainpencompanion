require 'rails_helper'

describe MacroCluster do
  describe '#without_review' do
    let!(:macro_cluster) { create(:macro_cluster) }

    subject { described_class.without_review }

    it 'returns clusters without any ink reviews' do
      expect(subject).to eq([macro_cluster])
    end

    it 'does not return a cluster with a new ink review' do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: nil)
      expect(subject).to be_empty
    end

    it 'does not return a cluster with an approved ink review' do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: Time.now, rejected_at: nil)
      expect(subject).to be_empty
    end

    it 'returns a cluster with a rejected review' do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: Time.now)
      expect(subject).to eq([macro_cluster])
    end

    it 'returns a cluster with multiple rejected reviews' do
      create_list(:ink_review, 2, macro_cluster: macro_cluster, approved_at: nil, rejected_at: Time.now)
      expect(subject.count).to eq(1)
      expect(subject).to eq([macro_cluster])
    end

    it 'does not return a cluster with an approved and a reject review' do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: Time.now, rejected_at: nil)
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: Time.now)
      expect(subject).to be_empty
    end

    it 'does not return a cluster with a new and a rejected review' do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: nil)
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: Time.now)
      expect(subject).to be_empty
    end
  end
end
