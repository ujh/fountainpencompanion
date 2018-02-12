require 'rails_helper'

describe CurrentlyInked do

  fixtures :users, :collected_inks, :collected_pens

  describe 'validations' do

    let(:user) { users(:moni) }

    before(:each) do
      subject.user = users(:moni)
    end

    it 'fails if the ink belongs to another user' do
      subject.collected_ink = collected_inks(:toms_marine)
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_ink)
    end

    it 'validates if the ink belongs to the same user' do
      subject.collected_ink = collected_inks(:monis_marine)
      expect(subject).to be_invalid
      expect(subject.errors).to_not include(:collected_ink)
    end

    it 'fails if the pen belongs to another user' do
      subject.collected_pen = collected_pens(:toms_platinum)
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_pen)
    end

    it 'validates if the pen belongs to the same user' do
      subject.collected_pen = collected_pens(:monis_wing_sung)
      expect(subject).to be_invalid
      expect(subject.errors).to_not include(:collected_pen)
    end

  end

end
