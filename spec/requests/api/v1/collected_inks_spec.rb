require "rails_helper"

describe Api::V1::CollectedInksController do
  describe "GET /index" do
    it "requires authentication" do
      get "/api/v1/collected_inks", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "returns all inks in alphabetical order" do
        create(:collected_ink, user: user, brand_name: "Aurora", ink_name: "Black")
        create(:collected_ink, user: user, brand_name: "Waldmann", ink_name: "Blue")
        create(:collected_ink, user: user, brand_name: "Pilot", ink_name: "Blue-Black")
        get "/api/v1/collected_inks", headers: { "ACCEPT" => "application/json" }

        expect(json).to include(
          data: [
            hash_including(attributes: hash_including(brand_name: "Aurora")),
            hash_including(attributes: hash_including(brand_name: "Pilot")),
            hash_including(attributes: hash_including(brand_name: "Waldmann"))
          ]
        )
      end

      it "does not return data from other users" do
        create(:collected_ink)

        get "/api/v1/collected_inks", headers: { "ACCEPT" => "application/json" }
        expect(json[:data]).to be_empty
      end

      it "allows specifying the fields to return" do
        create(:collected_ink, user: user, brand_name: "Aurora", ink_name: "Black")
        get "/api/v1/collected_inks",
            params: {
              fields: {
                collected_ink: "brand_name,ink_name"
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(
          data: [hash_including(attributes: { brand_name: "Aurora", ink_name: "Black" })]
        )
      end

      it "allows supports pagination" do
        create(:collected_ink, user: user, brand_name: "Aurora", ink_name: "Black")
        create(:collected_ink, user: user, brand_name: "Waldmann", ink_name: "Blue")
        create(:collected_ink, user: user, brand_name: "Pilot", ink_name: "Blue-Black")

        get "/api/v1/collected_inks",
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
          data: [hash_including(attributes: hash_including(brand_name: "Pilot"))],
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
        create(:collected_ink, user: user)
        get "/api/v1/collected_inks", headers: { "ACCEPT" => "application/json" }

        expect(json).to include(
          data: [
            hash_including(
              attributes:
                hash_including(
                  :brand_name,
                  :line_name,
                  :ink_name,
                  :maker,
                  :color,
                  :kind,
                  :swabbed,
                  :used,
                  :comment,
                  :private_comment,
                  :private,
                  :archived,
                  :archived_on,
                  :usage,
                  :daily_usage,
                  :last_used_on,
                  :ink_id,
                  :created_at
                )
            )
          ]
        )
      end

      it "can return only archived entries" do
        active = create(:collected_ink, user: user)
        archived = create(:collected_ink, user: user, archived_on: 2.days.ago)

        get "/api/v1/collected_inks",
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
        active = create(:collected_ink, user: user)
        archived = create(:collected_ink, user: user, archived_on: 2.days.ago)

        get "/api/v1/collected_inks",
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

      it "can sort by date added (newest first)" do
        older = create(:collected_ink, user: user, brand_name: "Aurora", created_at: 2.days.ago)
        newer = create(:collected_ink, user: user, brand_name: "Waldmann", created_at: 1.day.ago)

        get "/api/v1/collected_inks",
            params: {
              sort: "date_added"
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json[:data].map { |d| d[:id] }).to eq([newer.id.to_s, older.id.to_s])
      end

      it "can sort by date added (oldest first)" do
        older = create(:collected_ink, user: user, brand_name: "Aurora", created_at: 2.days.ago)
        newer = create(:collected_ink, user: user, brand_name: "Waldmann", created_at: 1.day.ago)

        get "/api/v1/collected_inks",
            params: {
              sort: "date_added_asc"
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json[:data].map { |d| d[:id] }).to eq([older.id.to_s, newer.id.to_s])
      end

      it "can filter by swabbed status" do
        swabbed = create(:collected_ink, user: user, swabbed: true)
        not_swabbed = create(:collected_ink, user: user, swabbed: false)

        get "/api/v1/collected_inks",
            params: {
              filter: {
                swabbed: "true"
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(data: [hash_including(id: swabbed.id.to_s)])
      end

      it "can filter by used status" do
        used = create(:collected_ink, user: user, used: true)
        not_used = create(:collected_ink, user: user, used: false)

        get "/api/v1/collected_inks",
            params: {
              filter: {
                used: "true"
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(data: [hash_including(id: used.id.to_s)])
      end

      it "can filter by macro_cluster_id" do
        macro_cluster1 = create(:macro_cluster)
        macro_cluster2 = create(:macro_cluster)
        micro_cluster1 = create(:micro_cluster, macro_cluster: macro_cluster1)
        micro_cluster2 = create(:micro_cluster, macro_cluster: macro_cluster2)
        ink1 = create(:collected_ink, user: user, micro_cluster: micro_cluster1)
        ink2 = create(:collected_ink, user: user, micro_cluster: micro_cluster2)

        get "/api/v1/collected_inks",
            params: {
              filter: {
                macro_cluster_id: macro_cluster1.id
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json[:data].length).to eq(1)
        expect(json).to include(data: [hash_including(id: ink1.id.to_s)])
      end

      it "returns no inks when filtering by macro_cluster_id with no matches" do
        macro_cluster = create(:macro_cluster)
        ink_without_cluster = create(:collected_ink, user: user)

        get "/api/v1/collected_inks",
            params: {
              filter: {
                macro_cluster_id: macro_cluster.id
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json[:data]).to be_empty
      end
    end
  end
end
