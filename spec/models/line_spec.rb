require 'rails_helper'

describe Line do

  describe '#search' do

    it 'does not fail when term is nil' do
      expect { described_class.search(nil) }.to_not raise_error
    end

  end

end
