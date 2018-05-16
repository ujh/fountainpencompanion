require 'rails_helper'

RSpec.describe User, type: :model do
  let(:moni) { create(:user) }
  let(:tom) { create(:user) }
  let(:moni_marine) { create(:collected_ink, user: moni, ink_name: 'Marine') }
  let(:moni_syrah) { create(:collected_ink, user: moni, ink_name: 'Syrah') }
  let(:tom_marine) { create(:collected_ink, user: tom, ink_name: 'Marine') }
  let(:moni_fire_and_ice) { create(:collected_ink, user: moni, brand_name: 'Robert Oster', line_name: 'Signature', ink_name: 'Fire & Ice') }
  let(:tom_twilight) { create(:collected_ink, user: tom, brand_name: 'Pilot', line_name: 'Iroshizuku', ink_name: 'KonPeki') }

  before do
    moni_marine
    tom_marine
    moni_fire_and_ice
    moni_syrah
    tom_twilight
  end

  describe '#possibly_wanted_inks_from' do
    it 'returns the inks of the second user that the first user does not have' do
      expect(moni.possibly_wanted_inks_from(tom)).to match_array([moni_fire_and_ice, moni_syrah])
    end
  end

  describe '#possibly_interesting_inks_for' do
    it 'returns the inks that the second user does not have' do
      expect(moni.possibly_interesting_inks_for(tom)).to eq([tom_twilight])
    end
  end
end
