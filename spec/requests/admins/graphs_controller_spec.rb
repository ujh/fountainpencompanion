require 'rails_helper'

describe Admins::GraphsController do
  let(:admin) { create(:admin) }

  describe '#show' do
    it 'requires authentication' do
      get '/admins/graphs/signups'
      expect(response).to redirect_to(new_admin_session_path)
    end

    context 'signed in' do
      before(:each) do
        sign_in(admin)
      end

      it 'returns the signups data' do
        create(:user, created_at: 2.days.ago)
        create(:user, created_at: 1.day.ago)
        create(:user, created_at: 2.days.ago, confirmed_at: nil)
        create(:user, created_at: 1.day.ago, confirmed_at: nil, bot: true)
        get '/admins/graphs/signups'
        expect(response).to be_successful
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json).to eq([{
          data: [
            [2.days.ago.at_beginning_of_day.to_i*1000, 1],
            [1.day.ago.at_beginning_of_day.to_i*1000, 1]
          ],
          name: 'Confirmed signups'
        }, {
          data: [
            [2.days.ago.at_beginning_of_day.to_i*1000, 2],
            [1.day.ago.at_beginning_of_day.to_i*1000, 1]
          ],
          name: 'All signups'
        }, {
          data: [
            [1.day.ago.at_beginning_of_day.to_i*1000, 1]
          ],
          name: 'Bot signups'
        }])
      end

      it 'returns the collected inks data' do
        create(:collected_ink, created_at: 2.days.ago)
        create(:collected_ink, created_at: 1.day.ago)
        get '/admins/graphs/collected-inks'
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to eq([
          [2.days.ago.at_beginning_of_day.to_i*1000, 1],
          [1.day.ago.at_beginning_of_day.to_i*1000, 1]
        ])
      end

      it 'returns the collected pens data' do
        create(:collected_pen, created_at: 2.days.ago)
        create(:collected_pen, created_at: 1.day.ago)
        get '/admins/graphs/collected-pens'
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to eq([
          [2.days.ago.at_beginning_of_day.to_i*1000, 1],
          [1.day.ago.at_beginning_of_day.to_i*1000, 1]
        ])
      end

      it 'returns the currently inked data' do
        create(:currently_inked, created_at: 2.days.ago)
        create(:currently_inked, created_at: 1.day.ago)
        get '/admins/graphs/currently-inked'
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to eq([
          [2.days.ago.at_beginning_of_day.to_i*1000, 1],
          [1.day.ago.at_beginning_of_day.to_i*1000, 1]
        ])
      end

      it 'returns the usage records data' do
        create(:usage_record, created_at: 2.days.ago)
        create(:usage_record, created_at: 1.day.ago)
        get '/admins/graphs/usage-records'
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to eq([
          [2.days.ago.at_beginning_of_day.to_i*1000, 1],
          [1.day.ago.at_beginning_of_day.to_i*1000, 1]
        ])
      end
    end
  end
end
