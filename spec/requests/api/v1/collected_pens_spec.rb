require "rails_helper"

describe Api::V1::CollectedPensController do
  describe "GET /index" do
    it "requires authentication" do
      get "/api/v1/collected_pens", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "returns all pens in alphabetical order" do
        create(:collected_pen, user: user, brand: "Aurora", model: "Optima")
        create(:collected_pen, user: user, brand: "Waldmann", model: "Liberty")
        create(:collected_pen, user: user, brand: "Pilot", model: "Custom 823")
        get "/api/v1/collected_pens",
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(
          data: [
            hash_including(attributes: hash_including(brand: "Aurora")),
            hash_including(attributes: hash_including(brand: "Pilot")),
            hash_including(attributes: hash_including(brand: "Waldmann"))
          ]
        )
      end

      it "does not return data from other users" do
        create(:collected_pen)

        get "/api/v1/collected_pens",
            headers: {
              "ACCEPT" => "application/json"
            }
        expect(json[:data]).to be_empty
      end

      it "allows specifying the fields to return" do
        create(:collected_pen, user: user, brand: "Aurora", model: "Optima")
        get "/api/v1/collected_pens",
            params: {
              fields: {
                collected_pen: "brand,model"
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(
          data: [
            hash_including(attributes: { brand: "Aurora", model: "Optima" })
          ]
        )
      end

      it "allows supports pagination" do
        create(:collected_pen, user: user, brand: "Aurora", model: "Optima")
        create(:collected_pen, user: user, brand: "Waldmann", model: "Liberty")
        create(:collected_pen, user: user, brand: "Pilot", model: "Custom 823")

        get "/api/v1/collected_pens",
            params: {
              page: {
                number: 2,
                size: 1
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to match(
          data: [hash_including(attributes: hash_including(brand: "Pilot"))],
          meta: {
            pagination: {
              total_pages: 3,
              current_page: 2,
              next_page: 3,
              prev_page: 1
            }
          }
        )
      end

      it "returns all fields by default" do
        create(:collected_pen, user: user)
        get "/api/v1/collected_pens",
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(
          data: [
            hash_including(
              attributes:
                hash_including(
                  :brand,
                  :model,
                  :nib,
                  :color,
                  :comment,
                  :archived,
                  :usage,
                  :daily_usage,
                  :last_inked,
                  :last_cleaned,
                  :created_at
                )
            )
          ]
        )
      end

      it "can return only archived entries" do
        active = create(:collected_pen, user: user)
        archived = create(:collected_pen, user: user, archived_on: 2.days.ago)

        get "/api/v1/collected_pens",
            params: {
              filter: {
                archived: "true"
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(data: [hash_including(id: archived.id.to_s)])
      end

      it "can return only active entries" do
        active = create(:collected_pen, user: user)
        archived = create(:collected_pen, user: user, archived_on: 2.days.ago)

        get "/api/v1/collected_pens",
            params: {
              filter: {
                archived: "false"
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(data: [hash_including(id: active.id.to_s)])
      end
    end
  end
end
