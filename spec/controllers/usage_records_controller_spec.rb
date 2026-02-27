require "rails_helper"

describe UsageRecordsController do
  render_views

  let(:user) { create(:user) }

  describe "#create" do
    let(:currently_inked) { create(:currently_inked, user: user, inked_on: 30.days.ago.to_date) }

    it "requires authentication" do
      post :create, params: { currently_inked_id: currently_inked.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "creates a usage record for today" do
        expect do
          post :create, params: { currently_inked_id: currently_inked.id }, format: :json
          expect(response).to have_http_status(:created)
        end.to change { UsageRecord.count }.from(0).to(1)
        expect(currently_inked.usage_records.count).to eq(1)
        usage_record = currently_inked.usage_records.first
        expect(usage_record.used_on).to eq(Date.today)
      end

      it "only creates one record for a given day" do
        expect do
          post :create, params: { currently_inked_id: currently_inked.id }, format: :json
          expect(response).to have_http_status(:created)
          post :create, params: { currently_inked_id: currently_inked.id }, format: :json
          expect(response).to have_http_status(:created)
        end.to change { UsageRecord.count }.from(0).to(1)
      end

      it "creates a usage record for a specific past date" do
        expect do
          post :create,
               params: {
                 currently_inked_id: currently_inked.id,
                 used_on: 2.days.ago.to_date.to_s
               },
               format: :json
          expect(response).to have_http_status(:created)
        end.to change { UsageRecord.count }.from(0).to(1)
        expect(currently_inked.usage_records.first.used_on).to eq(2.days.ago.to_date)
      end

      it "returns unprocessable_entity for invalid date" do
        post :create,
             params: {
               currently_inked_id: currently_inked.id,
               used_on: 1.day.from_now.to_date.to_s
             },
             format: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns not_found for missing currently_inked" do
        post :create, params: { currently_inked_id: 0 }, format: :json
        expect(response).to have_http_status(:not_found)
      end

      it "redirects with flash on HTML create" do
        post :create, params: { currently_inked_id: currently_inked.id }
        expect(response).to redirect_to(usage_records_path)
        expect(flash[:notice]).to eq("Usage record created.")
      end

      it "redirects with error flash for invalid date on HTML create" do
        post :create,
             params: {
               currently_inked_id: currently_inked.id,
               used_on: 1.day.from_now.to_date.to_s
             }
        expect(response).to redirect_to(usage_records_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "#index" do
    it "requires authentication" do
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "renders the entries" do
        get :index
        expect(response).to be_successful
      end
    end
  end

  describe "#destroy" do
    let(:currently_inked) { create(:currently_inked, user: user) }
    let!(:usage_record) { create(:usage_record, currently_inked: currently_inked) }

    it "requires authentication" do
      delete :destroy, params: { id: usage_record.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "destroys the entry" do
        expect do delete :destroy, params: { id: usage_record.id } end.to change {
          UsageRecord.count
        }.by(-1)
      end

      it "does not delete other users records" do
        usage_record = create(:usage_record)
        expect do delete :destroy, params: { id: usage_record.id } end.to_not change {
          UsageRecord.count
        }
      end

      it "redirects back to the index page" do
        delete :destroy, params: { id: usage_record.id }
        expect(response).to redirect_to(usage_records_path)
      end
    end
  end
end
