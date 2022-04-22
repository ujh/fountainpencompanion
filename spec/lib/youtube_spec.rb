require 'rails_helper'

describe Youtube do
  subject { described_class.new(channel_id: 'channel_id', client: client) }

  describe '#channel_name' do
    let(:client) do
      double(
        :client,
        list_channels: double(
          :channels,
          items: [double(
            :item,
            snippet: double(:snippet, title: 'channel_name')
          )]
        )
      )
    end

    it 'returns the channel name' do
      expect(subject.channel_name).to eq('channel_name')
    end
  end
end
