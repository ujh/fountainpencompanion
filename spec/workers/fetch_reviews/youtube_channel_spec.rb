require 'rails_helper'

describe FetchReviews::YoutubeChannel do
  subject { described_class.new }

  let(:client) do
    double(
      :client,
      fetch_videos: (0...10).map do |i|
        {
          title: "title#{i}",
          url: "url#{i}"
        }
      end
    )
  end

  before do
    allow(subject).to receive(:client).and_return(client)
  end

  context 'back catalog imported' do
    let(:channel) { create(:you_tube_channel, back_catalog_imported: true) }

    it 'submits the first five reviews' do
      expect do
        subject.perform(channel.channel_id)
      end.to change { FetchReviews::SubmitReview.jobs.count }.by(5)
    end

    it 'submits the correct data' do
      macro_cluster = create(:macro_cluster)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
      create(:collected_ink, micro_cluster: micro_cluster, brand_name: 'title0')
      subject.perform(channel.channel_id)
      job = FetchReviews::SubmitReview.jobs.first
      expect(job['args']).to eq([
        'url0', macro_cluster.id
      ])
    end
  end

  context 'back catalog not imported' do
    let(:channel) { create(:you_tube_channel, back_catalog_imported: false) }

    it 'submits all reviews' do
      expect do
        subject.perform(channel.channel_id)
      end.to change { FetchReviews::SubmitReview.jobs.count }.by(10)
    end

    it 'sets back_catalog_imported to true' do
      expect do
        subject.perform(channel.channel_id)
      end.to change { channel.reload.back_catalog_imported }.to(true)
    end
  end
end
