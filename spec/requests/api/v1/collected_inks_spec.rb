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
    end

    # Also confirm that non-GET methods can be token-only (in other words: we
    # have correctly disabled CSRF from our REST API)
    context "with only token authentication" do
      let(:user) { create(:user) }
      let(:auth_token) { create(:authentication_token, user: user) }

      around do |example|
        # Temporarily enable CSRF protection for these tests
        original_value = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        example.run
        ActionController::Base.allow_forgery_protection = original_value
      end

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
                 "CONTENT_TYPE" => "application/json",
                 "AUTHORIZATION" => "Bearer #{auth_token.id}.#{auth_token.token}"
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

      it "returns validation errors for invalid data" do
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
               "CONTENT_TYPE" => "application/json",
               "AUTHORIZATION" => "Bearer #{auth_token.id}.#{auth_token.token}"
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:errors]).to be_present
      end

      it "returns 401 for invalid token" do
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
               "CONTENT_TYPE" => "application/json",
               "AUTHORIZATION" => "Bearer 999.invalid_token"
             },
             as: :json

        expect(response).to have_http_status(:unauthorized)
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

      it "can set the archived date" do
        ink = create(:collected_ink, user: user, archived_on: nil)

        patch "/api/v1/collected_inks/#{ink.id}",
              params: {
                data: {
                  type: "collected_ink",
                  attributes: {
                    archived_on: "2024-01-01"
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
          data: hash_including(attributes: hash_including(archived_on: "2024-01-01"))
        )
        expect(ink.reload.archived_on).to eq(Date.parse("2024-01-01"))
        expect(ink).to be_archived
      end

      it "can clear the archived date" do
        ink = create(:collected_ink, user: user, archived_on: 2.days.ago)

        patch "/api/v1/collected_inks/#{ink.id}",
              params: {
                data: {
                  type: "collected_ink",
                  attributes: {
                    archived_on: nil
                  }
                }
              },
              headers: {
                "ACCEPT" => "application/json",
                "CONTENT_TYPE" => "application/json"
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(json).to include(data: hash_including(attributes: hash_including(archived_on: nil)))
        expect(ink.reload.archived_on).to be_nil
        expect(ink).not_to be_archived
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
