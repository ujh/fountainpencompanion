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

  describe "GET /show" do
    it "requires authentication" do
      ink = create(:collected_ink)
      get "/api/v1/collected_inks/#{ink.id}", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "returns the requested ink" do
        ink = create(:collected_ink, user: user, brand_name: "Pilot", ink_name: "Kon-peki")
        get "/api/v1/collected_inks/#{ink.id}", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json).to include(
          data:
            hash_including(
              id: ink.id.to_s,
              attributes: hash_including(brand_name: "Pilot", ink_name: "Kon-peki")
            )
        )
      end

      it "returns 404 for another user's ink" do
        other_ink = create(:collected_ink)
        get "/api/v1/collected_inks/#{other_ink.id}", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for non-existent ink" do
        get "/api/v1/collected_inks/999999", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /create" do
    it "requires authentication" do
      post "/api/v1/collected_inks",
           params: {
             data: {
               type: "collected_ink",
               attributes: {
                 brand_name: "Pilot",
                 ink_name: "Blue"
               }
             }
           },
           headers: {
             "ACCEPT" => "application/json",
             "CONTENT_TYPE" => "application/json"
           },
           as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "creates a new collected ink" do
        expect do
          post "/api/v1/collected_inks",
               params: {
                 data: {
                   type: "collected_ink",
                   attributes: {
                     brand_name: "Pilot",
                     line_name: "Iroshizuku",
                     ink_name: "Kon-peki",
                     kind: "bottle",
                     color: "#0066CC"
                   }
                 }
               },
               headers: {
                 "ACCEPT" => "application/json",
                 "CONTENT_TYPE" => "application/json"
               },
               as: :json
        end.to change(user.collected_inks, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json).to include(
          data:
            hash_including(
              attributes:
                hash_including(
                  brand_name: "Pilot",
                  line_name: "Iroshizuku",
                  ink_name: "Kon-peki",
                  kind: "bottle",
                  color: "#0066CC"
                )
            )
        )
      end

      it "returns validation errors for brand_name that is too long" do
        post "/api/v1/collected_inks",
             params: {
               data: {
                 type: "collected_ink",
                 attributes: {
                   brand_name: "a" * 101,
                   ink_name: "Blue"
                 }
               }
             },
             headers: {
               "ACCEPT" => "application/json",
               "CONTENT_TYPE" => "application/json"
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:errors]).to be_present
      end

      it "creates an archived ink when archived is true" do
        post "/api/v1/collected_inks",
             params: {
               data: {
                 type: "collected_ink",
                 attributes: {
                   brand_name: "Pilot",
                   ink_name: "Blue",
                   archived: true
                 }
               }
             },
             headers: {
               "ACCEPT" => "application/json",
               "CONTENT_TYPE" => "application/json"
             },
             as: :json

        expect(response).to have_http_status(:created)
        expect(user.collected_inks.last.archived?).to be true
      end
    end
  end

  describe "PATCH /update" do
    it "requires authentication" do
      ink = create(:collected_ink)
      patch "/api/v1/collected_inks/#{ink.id}",
            params: {
              data: {
                type: "collected_ink",
                attributes: {
                  brand_name: "Updated"
                }
              }
            },
            headers: {
              "ACCEPT" => "application/json",
              "CONTENT_TYPE" => "application/json"
            },
            as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "updates the collected ink" do
        ink = create(:collected_ink, user: user, brand_name: "Pilot", ink_name: "Blue")

        patch "/api/v1/collected_inks/#{ink.id}",
              params: {
                data: {
                  type: "collected_ink",
                  attributes: {
                    brand_name: "Sailor",
                    comment: "Great ink!"
                  }
                }
              },
              headers: {
                "ACCEPT" => "application/json",
                "CONTENT_TYPE" => "application/json"
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(json).to include(
          data:
            hash_including(attributes: hash_including(brand_name: "Sailor", comment: "Great ink!"))
        )
        expect(ink.reload.brand_name).to eq("Sailor")
      end

      it "returns 404 for another user's ink" do
        other_ink = create(:collected_ink)

        patch "/api/v1/collected_inks/#{other_ink.id}",
              params: {
                data: {
                  type: "collected_ink",
                  attributes: {
                    brand_name: "Updated"
                  }
                }
              },
              headers: {
                "ACCEPT" => "application/json",
                "CONTENT_TYPE" => "application/json"
              },
              as: :json

        expect(response).to have_http_status(:not_found)
      end

      it "returns validation errors for invalid data" do
        ink = create(:collected_ink, user: user)

        patch "/api/v1/collected_inks/#{ink.id}",
              params: {
                data: {
                  type: "collected_ink",
                  attributes: {
                    brand_name: "a" * 101
                  }
                }
              },
              headers: {
                "ACCEPT" => "application/json",
                "CONTENT_TYPE" => "application/json"
              },
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:errors]).to be_present
      end

      it "archives an ink when archived is set to true" do
        ink = create(:collected_ink, user: user)
        expect(ink.archived?).to be false

        patch "/api/v1/collected_inks/#{ink.id}",
              params: {
                data: {
                  type: "collected_ink",
                  attributes: {
                    archived: true
                  }
                }
              },
              headers: {
                "ACCEPT" => "application/json",
                "CONTENT_TYPE" => "application/json"
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(ink.reload.archived?).to be true
        expect(json[:data][:attributes][:archived]).to be true
      end

      it "unarchives an ink when archived is set to false" do
        ink = create(:collected_ink, user: user, archived_on: Date.current)
        expect(ink.archived?).to be true

        patch "/api/v1/collected_inks/#{ink.id}",
              params: {
                data: {
                  type: "collected_ink",
                  attributes: {
                    archived: false
                  }
                }
              },
              headers: {
                "ACCEPT" => "application/json",
                "CONTENT_TYPE" => "application/json"
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(ink.reload.archived?).to be false
        expect(json[:data][:attributes][:archived]).to be false
      end
    end
  end

  describe "DELETE /destroy" do
    it "requires authentication" do
      ink = create(:collected_ink)
      delete "/api/v1/collected_inks/#{ink.id}", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "deletes the collected ink" do
        ink = create(:collected_ink, user: user)

        expect do
          delete "/api/v1/collected_inks/#{ink.id}", headers: { "ACCEPT" => "application/json" }
        end.to change(user.collected_inks, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it "returns 404 for another user's ink" do
        other_ink = create(:collected_ink)

        delete "/api/v1/collected_inks/#{other_ink.id}", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for non-existent ink" do
        delete "/api/v1/collected_inks/999999", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
