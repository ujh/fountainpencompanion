require 'rails_helper'

describe User do
  fixtures :users, :collected_inks

  describe '#possibly_wanted_inks_from' do

    it 'returns the inks of the second user that the first user does not have' do
      expect(users(:moni).possibly_wanted_inks_from(users(:tom))).to match_array([
        collected_inks(:monis_fire_and_ice),
        collected_inks(:monis_syrah)
      ])
    end
  end

  describe '#possibly_interesting_inks_for' do

    it 'returns the inks that the second user does not have' do
      expect(users(:tom).possibly_interesting_inks_for(users(:moni))).to eq([
        collected_inks(:monis_fire_and_ice)
      ])
    end
  end
end
