require 'rails_helper'

describe Brand do

  describe '#search' do

    it 'does not fail when term is nil' do
      expect { Brand.search(nil) }.to_not raise_error
    end

  end

end
