require "rails_helper"
require "csv"

describe Admins::UsersController do
  let(:admin) { create(:user, :admin) }

  describe "#index" do
    it "requires authentication" do
      get "/admins/users"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders" do
        get "/admins/users"
        expect(response).to be_successful
      end
    end
  end

  describe "#ink_import" do
    include ActionDispatch::TestProcess

    let(:csv) do
      name = Rails.root.join("tmp", "import.csv")
      CSV.open(name, "w") do |csv|
        csv << %w[brand_name line_name ink_name kind private]
        csv << ["Diamine", "Shimmertastic", "Purple Pazzazz", "bottle", "x"]
        csv << ["J. Herbin", "", "Vert Olive", "sample"]
        csv << ["Pelikan", " Edelstein ", "Aventurine", "sample"]
      end
      name
    end
    let(:file_upload) { fixture_file_upload(csv) }
    let(:user) { create(:user) }

    it "requires authentication" do
      post "/admins/users/#{user.id}/ink_import", params: { file: file_upload }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "processes the CSV file" do
        expect do
          post "/admins/users/#{user.id}/ink_import",
               params: {
                 file: file_upload
               }
          expect(ImportCollectedInk.jobs.size).to eq(3)
          ImportCollectedInk.drain
        end.to change { user.collected_inks.count }.by(3)
        expect(
          user.collected_inks.find_by(ink_name: "Purple Pazzazz")
        ).to be_private
        expect(
          user.collected_inks.find_by(ink_name: "Vert Olive")
        ).to_not be_private
        # Removes whitespace
        expect(
          user.collected_inks.find_by(ink_name: "Aventurine").line_name
        ).to eq("Edelstein")
      end
    end
  end

  describe "#pen_import" do
    include ActionDispatch::TestProcess

    let(:csv) do
      name = Rails.root.join("tmp", "import.csv")
      CSV.open(name, "w") do |csv|
        csv << %w[brand model comment nib color]
        csv << ["PenBBS", "456", "comment", "F", "  blue  "]
      end
      name
    end
    let(:file_upload) { fixture_file_upload(csv) }
    let(:user) { create(:user) }

    it "requires authentication" do
      post "/admins/users/#{user.id}/pen_import", params: { file: file_upload }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "processes the CSV file" do
        expect do
          post "/admins/users/#{user.id}/pen_import",
               params: {
                 file: file_upload
               }
          expect(ImportCollectedPen.jobs.size).to eq(1)
          ImportCollectedPen.drain
        end.to change { user.collected_pens.count }.by(1)
        pen = user.collected_pens.last
        expect(pen.brand).to eq("PenBBS")
        expect(pen.model).to eq("456")
        expect(pen.nib).to eq("F")
        expect(pen.color).to eq("blue") # strips whitespace
        expect(pen.comment).to eq("comment")
      end

      it "updates an existing pen" do
        pen =
          create(
            :collected_pen,
            user:,
            brand: "PenBBS",
            model: "456",
            nib: "F",
            color: "blue"
          )

        expect do
          post "/admins/users/#{user.id}/pen_import",
               params: {
                 file: file_upload
               }
          expect(ImportCollectedPen.jobs.size).to eq(1)
          ImportCollectedPen.drain
        end.not_to(change { user.collected_pens.count })

        expect(pen.reload.comment).to eq("comment")
      end
    end
  end

  describe "#to_review" do
    it "requires authentication" do
      get "/admins/users/to_review"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "shows one user" do
        users = create_list(:user, 2, review_blurb: true)
        get "/admins/users/to_review"
        expect(response).to be_successful
      end

      it "redirects to the dashboard if no user to review" do
        get "/admins/users/to_review"
        expect(response).to redirect_to(admins_dashboard_path)
      end
    end
  end

  describe "approve" do
    let(:user) { create(:user, review_blurb: true) }

    it "requires authentication" do
      put "/admins/users/#{user.id}/approve"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "sets review_blurb to false" do
        put "/admins/users/#{user.id}/approve"
        expect(user.reload.review_blurb).to be false
      end

      it "redirects to review page" do
        put "/admins/users/#{user.id}/approve"
        expect(response).to redirect_to(to_review_admins_users_path)
      end
    end
  end

  describe "#destroy" do
    let!(:user) { create(:user, review_blurb: true) }

    it "requires authentication" do
      delete "/admins/users/#{user.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "marks user as spam" do
        delete "/admins/users/#{user.id}"
        user.reload
        expect(user.review_blurb).to be false
        expect(user).to be_spam
        expect(user.spam_reason).to eq("manually-marked-as-spam")
      end

      it "redirects to the review page" do
        delete "/admins/users/#{user.id}"
        expect(response).to redirect_to(to_review_admins_users_path)
      end
    end
  end
end
