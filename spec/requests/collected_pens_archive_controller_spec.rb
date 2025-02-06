require "rails_helper"

describe CollectedPensArchiveController do
  let(:user) { create(:user) }
  let(:collected_pen) { create(:collected_pen, user:, archived_on: Date.today) }

  describe "#index" do
    it "requires authentication" do
      get "/collected_pens_archive"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "correctly renders the page" do
        collected_pen.update!(archived_on: Date.today)
        get "/collected_pens_archive"
        expect(response).to be_successful
        expect(response.body).to include(collected_pen.brand)
      end

      it "does not include unarchived pens" do
        collected_pen.update!(archived_on: nil)
        get "/collected_pens_archive"
        expect(response).to be_successful
        expect(response.body).to_not include(collected_pen.brand)
      end
    end
  end

  describe "#edit" do
    it "requires authentication" do
      get "/collected_pens_archive/#{collected_pen.id}/edit"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "correctly renders the page" do
        get "/collected_pens_archive/#{collected_pen.id}/edit"
        expect(response).to be_successful
        expect(response.body).to include(collected_pen.brand)
      end

      it "does not show pens from other users" do
        pen = create(:collected_pen, archived_on: Date.today)
        get "/collected_pens_archive/#{pen.id}/edit"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "#update" do
    it "requires authentication" do
      put "/collected_pens_archive/#{collected_pen.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "correctly updates the pen" do
        expect do
          put "/collected_pens_archive/#{collected_pen.id}",
              params: {
                collected_pen: {
                  brand: "the brand"
                }
              }
        end.to change { collected_pen.reload.brand }.to("the brand")
        expect(response).to redirect_to(collected_pens_archive_index_path)
      end

      it "does not update when validations fail" do
        expect do
          put "/collected_pens_archive/#{collected_pen.id}",
              params: {
                collected_pen: {
                  brand: ""
                }
              }
        end.to_not(change { collected_pen.reload.brand })
      end

      it "does not update pens from other users" do
        pen = create(:collected_pen, archived_on: Date.today)
        expect do
          put "/collected_pens_archive/#{pen.id}", params: { collected_pen: { brand: "the brand" } }
          expect(response).to have_http_status(:not_found)
        end.to_not(change { pen.reload.brand })
      end
    end
  end

  describe "#unarchive" do
    it "requires authentication" do
      post "/collected_pens_archive/#{collected_pen.id}/unarchive"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "correctly unarchives the pen" do
        expect do post "/collected_pens_archive/#{collected_pen.id}/unarchive" end.to change {
          collected_pen.reload.archived?
        }.from(true).to(false)
        expect(response).to redirect_to(collected_pens_archive_index_path)
      end

      it "does not unarchive pens from other users" do
        pen = create(:collected_pen, archived_on: Date.today)
        expect do
          post "/collected_pens_archive/#{pen.id}/unarchive"
          expect(response).to have_http_status(:not_found)
        end.to_not(change { pen.reload.archived? })
      end
    end
  end

  describe "#destroy" do
    it "requires authentication" do
      delete "/collected_pens_archive/#{collected_pen.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) do
        collected_pen
        sign_in(user)
      end

      it "correctly deletes the pen" do
        expect do delete "/collected_pens_archive/#{collected_pen.id}" end.to change {
          user.collected_pens.count
        }.by(-1)
        expect(response).to redirect_to(collected_pens_archive_index_path)
      end

      it "does not unarchive pens from other users" do
        pen = create(:collected_pen)
        expect do
          delete "/collected_pens_archive/#{pen.id}"
          expect(response).to have_http_status(:not_found)
        end.to_not(change { CollectedPen.count })
      end
    end
  end
end
