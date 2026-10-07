require "rails_helper"

describe AccountsController do
  describe "#show" do
    it "requires authentication" do
      get "/account"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      let(:user) { create(:user, name: "the name") }

      before(:each) { sign_in(user) }

      it "renders a page" do
        get "/account"
        expect(response).to be_successful
      end

      it "renders json if requested" do
        get "/account.jsonapi"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json["data"]["id"]).to eq(user.id.to_s)
        expect(json["data"]["type"]).to eq("user")
        expect(json["data"]["attributes"]["name"]).to eq("the name")
        expect(json["data"]["attributes"]["preferences"]).to eq({})
      end

      it "does not include collected_inks by default" do
        create(:collected_ink, user: user)
        get "/account.jsonapi"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json["included"]).to be_nil
      end

      it "includes public inks when requested" do
        ink = create(:collected_ink, user: user)
        get "/account.jsonapi?include=collected_inks"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json["data"]["relationships"]["collected_inks"]["data"]).to eq(
          [{ "type" => "collected_inks", "id" => ink.id.to_s }]
        )
        expect(json["included"].length).to eq(1)
      end

      it "does not include private inks" do
        create(:collected_ink, user: user, private: true)
        get "/account.jsonapi?include=collected_inks"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json["data"]["relationships"]["collected_inks"]["data"]).to eq([])
      end

      it "returns preferences" do
        user.update!(preferences: { "collected_inks_table_hidden_fields" => %w[nib color] })
        get "/account.jsonapi"
        json = JSON.parse(response.body)
        expect(json["data"]["attributes"]["preferences"]).to eq(
          "collected_inks_table_hidden_fields" => %w[nib color]
        )
      end
    end
  end

  describe "#update" do
    it "requires authentication" do
      put "/account"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      let(:user) { create(:user, name: "the name") }
      let(:jsonapi_headers) do
        { "Content-Type" => "application/vnd.api+json", "Accept" => "application/vnd.api+json" }
      end

      before(:each) { sign_in(user) }

      it "updates the user data" do
        put "/account", params: { user: { name: "new name" } }
        expect(response).to redirect_to(account_path)
        expect(user.reload.name).to eq("new name")
      end

      it "also supports json requests" do
        put "/account", params: { user: { name: "new name" } }, as: :json
        expect(response).to be_successful
        expect(user.reload.name).to eq("new name")
      end

      describe "blurb moderation" do
        it "enqueues the after save job when the blurb changes via html" do
          expect do
            put "/account", params: { user: { blurb: "Visit https://example.com" } }
          end.to change(AfterUserSaved.jobs, :count).by(1)
        end

        it "enqueues the after save job when the blurb changes via json" do
          expect do
            put "/account", params: { user: { blurb: "Visit https://example.com" } }, as: :json
          end.to change(AfterUserSaved.jobs, :count).by(1)
          expect(response).to be_successful
        end

        it "enqueues the after save job when the blurb changes via jsonapi" do
          expect do
            put "/account",
                params: { user: { blurb: "Visit https://example.com" } }.to_json,
                headers: jsonapi_headers
          end.to change(AfterUserSaved.jobs, :count).by(1)
          expect(response).to be_successful
        end

        it "does not enqueue the job when only the name changes" do
          expect do put "/account", params: { user: { name: "new name" } } end.not_to change(
            AfterUserSaved.jobs,
            :count
          )
        end

        it "does not enqueue the job when only preferences change" do
          expect do
            put "/account",
                params: { user: { preferences: { dashboard_widgets: [] } } }.to_json,
                headers: jsonapi_headers
          end.not_to change(AfterUserSaved.jobs, :count)
        end

        it "does not enqueue the job when the blurb is unchanged" do
          user.update!(blurb: "same")
          expect do
            put "/account", params: { user: { blurb: "same" } }, as: :json
          end.not_to change(AfterUserSaved.jobs, :count)
        end

        it "does not enqueue the job when the update fails" do
          expect do
            put "/account", params: { user: { blurb: "new", name: "x" * 101 } }, as: :json
          end.not_to change(AfterUserSaved.jobs, :count)
          expect(user.reload.blurb).not_to eq("new")
        end
      end

      describe "preferences" do
        it "updates preferences" do
          put "/account",
              params: {
                user: {
                  preferences: {
                    collected_inks_table_hidden_fields: %w[nib color]
                  }
                }
              }.to_json,
              headers: jsonapi_headers
          expect(response).to be_successful
          expect(user.reload.preferences).to eq(
            "collected_inks_table_hidden_fields" => %w[nib color]
          )
        end

        it "merges preferences without overwriting other keys" do
          user.update!(preferences: { "collected_inks_table_hidden_fields" => ["nib"] })
          put "/account",
              params: {
                user: {
                  preferences: {
                    collected_pens_table_hidden_fields: ["color"]
                  }
                }
              }.to_json,
              headers: jsonapi_headers
          expect(response).to be_successful
          expect(user.reload.preferences).to eq(
            "collected_inks_table_hidden_fields" => ["nib"],
            "collected_pens_table_hidden_fields" => ["color"]
          )
        end

        it "removes a preference key when set to null" do
          user.update!(preferences: { "collected_inks_table_hidden_fields" => ["nib"] })
          put "/account",
              params: {
                user: {
                  preferences: {
                    collected_inks_table_hidden_fields: nil
                  }
                }
              }.to_json,
              headers: jsonapi_headers
          expect(response).to be_successful
          expect(user.reload.preferences).to eq({})
        end

        it "ignores unknown preference keys" do
          put "/account",
              params: { user: { preferences: { unknown_key: ["nib"] } } }.to_json,
              headers: jsonapi_headers
          expect(response).to be_successful
          expect(user.reload.preferences).to eq({})
        end

        it "updates dashboard_widgets preference" do
          widgets = %w[inks_summary pens_summary]
          put "/account",
              params: { user: { preferences: { dashboard_widgets: widgets } } }.to_json,
              headers: jsonapi_headers
          expect(response).to be_successful
          expect(user.reload.preferences["dashboard_widgets"]).to eq(widgets)
        end

        it "removes dashboard_widgets when set to null" do
          user.update!(preferences: { "dashboard_widgets" => %w[inks_summary pens_summary] })
          put "/account",
              params: { user: { preferences: { dashboard_widgets: nil } } }.to_json,
              headers: jsonapi_headers
          expect(response).to be_successful
          expect(user.reload.preferences).to eq({})
        end

        it "returns updated user in jsonapi response" do
          put "/account",
              params: {
                user: {
                  preferences: {
                    collected_inks_table_hidden_fields: ["nib"]
                  }
                }
              }.to_json,
              headers: jsonapi_headers
          json = JSON.parse(response.body)
          expect(json["data"]["attributes"]["preferences"]).to eq(
            "collected_inks_table_hidden_fields" => ["nib"]
          )
        end
      end

      describe "malformed bodies" do
        it "rejects a JSON:API body that is not an object" do
          put "/account", params: "[]", headers: jsonapi_headers
          expect(response).to have_http_status(:bad_request)
        end

        it "rejects a user that is not an object" do
          put "/account", params: { user: "x" }.to_json, headers: jsonapi_headers
          expect(response).to have_http_status(:bad_request)
        end

        it "rejects preferences that are not an object" do
          put "/account", params: { user: { preferences: "abc" } }.to_json, headers: jsonapi_headers
          expect(response).to have_http_status(:bad_request)
        end

        it "rejects a non-object _jsonapi form field" do
          put "/account", params: { _jsonapi: "foo", user: { name: "new name" } }, as: :json
          expect(response).to have_http_status(:ok)
          expect(user.reload.name).to eq("new name")
        end
      end

      describe "validation failures" do
        it "returns 422 with errors for json requests" do
          put "/account", params: { user: { name: "x" * 101 } }, as: :json
          expect(response).to have_http_status(:unprocessable_content)
          expect(JSON.parse(response.body)["errors"]).to be_present
        end

        it "returns 422 with JSON:API errors for jsonapi requests" do
          put "/account", params: { user: { name: "x" * 101 } }.to_json, headers: jsonapi_headers
          expect(response).to have_http_status(:unprocessable_content)
          expect(JSON.parse(response.body)["errors"]).to eq(
            [
              {
                "title" => "Invalid name",
                "detail" => "Name is too long (maximum is 100 characters)",
                "source" => {
                }
              }
            ]
          )
        end

        it "rejects an invalid time zone" do
          put "/account", params: { user: { time_zone: "Not/AZone" } }, as: :json
          expect(response).to have_http_status(:unprocessable_content)
          expect(user.reload.time_zone).to be_blank
        end
      end
    end
  end
end
