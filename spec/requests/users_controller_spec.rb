require "rails_helper"

describe UsersController do
  describe "#index" do
    it "includes confirmed users" do
      user = create(:user, name: "the name")
      get "/users"
      expect(response).to be_successful
      expect(response.body).to include("the name")
      expect(response.body).to include("/users/#{user.id}")
    end

    it "does not include users that have no user name" do
      user = create(:user, name: "")
      get "/users"
      expect(response).to be_successful
      expect(response.body).to_not include("/users/#{user.id}")
    end

    it "does not include users marked as spam" do
      user = create(:user, name: "a name", spam: true)
      get "/users"
      expect(response).to be_successful
      expect(response.body).to_not include("/users/#{user.id}")
    end

    it "shows the patreon logo next to the correct user" do
      user = create(:user, name: "the name", patron: true)
      get "/users"
      expect(response).to be_successful
      expect(response.body).to include("fpc-patron-tiny")
    end
  end

  describe "#show" do
    it "returns the user data" do
      user = create(:user, name: "the name")
      get "/users/#{user.id}.jsonapi"
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json).to eq(
        "data" => {
          "id" => user.id.to_s,
          "type" => "user",
          "attributes" => {
            "name" => "the name"
          },
          "relationships" => {
            "collected_inks" => {
              "data" => []
            }
          }
        },
        "jsonapi" => {
          "version" => "1.0"
        }
      )
    end

    it "returns public inks" do
      ink = create(:collected_ink)
      user = ink.user
      get "/users/#{user.id}.jsonapi"
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json["data"]["relationships"]["collected_inks"]["data"]).to eq(
        [{ "type" => "collected_inks", "id" => ink.id.to_s }]
      )
      expect(json["included"]).to eq(
        [
          {
            "id" => ink.id.to_s,
            "type" => "collected_inks",
            "attributes" => {
              "brand_name" => ink.brand_name,
              "color" => ink.color,
              "comment" => ink.comment,
              "ink_id" => nil,
              "ink_name" => ink.ink_name,
              "kind" => ink.kind,
              "line_name" => ink.line_name,
              "maker" => ink.maker
            }
          }
        ]
      )
    end

    it "does not return private inks" do
      ink = create(:collected_ink, private: true)
      user = ink.user
      get "/users/#{user.id}.jsonapi"
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json["data"]["relationships"]["collected_inks"]["data"]).to eq([])
    end

    it "does not work for users marked as spam" do
      user = create(:user, name: "the name", spam: true)
      get "/users/#{user.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "works for users without a user name" do
      user = create(:user, name: "")
      get "/users/#{user.id}"
      expect(response).to be_successful
    end
  end
end
