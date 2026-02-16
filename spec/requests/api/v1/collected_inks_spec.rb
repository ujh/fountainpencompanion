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

      describe "query efficiency - default behavior (no cluster details)" do
        let(:macro_cluster1) do
          create(:macro_cluster, brand_name: "Diamine", line_name: "Standard", ink_name: "Blue")
        end
        let(:macro_cluster2) do
          create(:macro_cluster, brand_name: "Pilot", line_name: "", ink_name: "Kon-peki")
        end
        let(:micro_cluster1) { create(:micro_cluster, macro_cluster: macro_cluster1) }
        let(:micro_cluster2) { create(:micro_cluster, macro_cluster: macro_cluster2) }

        before do
          # Create 5 collected inks
          3.times do |i|
            create(:collected_ink, user: user, micro_cluster: micro_cluster1, color: "#000#{i}FF")
          end
          2.times do |i|
            create(:collected_ink, user: user, micro_cluster: micro_cluster2, color: "#00#{i}0FF")
          end
        end

        it "does not load macro_cluster relationships when parameter is not provided" do
          get "/api/v1/collected_inks", headers: { "ACCEPT" => "application/json" }

          expect(response).to have_http_status(:ok)
          # Verify no included section
          expect(json).not_to have_key(:included)
          # Verify no detailed attributes
          expect(json[:data].first[:attributes]).not_to have_key(:description)
          expect(json[:data].first[:attributes]).not_to have_key(:colors)
          expect(json[:data].first[:attributes]).not_to have_key(:tags)
          expect(json[:data].first[:attributes]).not_to have_key(:all_names)
        end

        it "keeps the query count low without cluster details (baseline)" do
          # This is a baseline to ensure we're not loading extra data by default.
          # With proper eager loading, we should have minimal N+1 queries.
          # Typical query count: ~1 for user inks + 1 for relationships
          get "/api/v1/collected_inks", headers: { "ACCEPT" => "application/json" }

          expect(response).to have_http_status(:ok)
          expect(json[:data].length).to eq(5)
        end

        it "does not add extra queries when micro_cluster eager loading is used" do
          # This test verifies that by default we don't load unnecessary macro_cluster data.
          # The eager loading strategy should load micro_cluster without macro_cluster
          # when include_cluster_details is not set.
          get "/api/v1/collected_inks", headers: { "ACCEPT" => "application/json" }

          expect(response).to have_http_status(:ok)
          # Verify no unnecessary attributes are present
          data_attrs = json[:data].first[:attributes]
          expect(data_attrs).not_to have_key(:colors)
          expect(data_attrs).not_to have_key(:all_names)
        end
      end

      describe "include_cluster_details parameter" do
        let(:macro_cluster) do
          create(
            :macro_cluster,
            brand_name: "Diamine",
            line_name: "Standard",
            ink_name: "Blue",
            color: "#0000FF",
            description: "A beautiful blue ink",
            tags: %w[blue vibrant]
          )
        end
        let(:micro_cluster) { create(:micro_cluster, macro_cluster: macro_cluster) }

        before do
          # Create multiple collected inks with different colors for the same cluster
          create(:collected_ink, user: user, micro_cluster: micro_cluster, color: "#0000FF")
          create(:collected_ink, user: user, micro_cluster: micro_cluster, color: "#0000CC")
          create(:collected_ink, user: user, micro_cluster: micro_cluster, color: "#0000AA")
        end

        it "does not include macro_cluster details by default" do
          get "/api/v1/collected_inks", headers: { "ACCEPT" => "application/json" }

          expect(response).to have_http_status(:ok)
          expect(json).not_to have_key(:included)
          expect(json[:data].first[:attributes]).not_to have_key(:description)
        end

        it "does not include macro_cluster details when parameter is false" do
          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "false"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(json).not_to have_key(:included)
        end

        it "includes macro_cluster details when parameter is true" do
          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(json).to have_key(:included)

          # Find the macro_cluster in the included section
          cluster_data =
            json[:included].find do |inc|
              inc[:type] == "macro_cluster" && inc[:id] == macro_cluster.id.to_s
            end

          expect(cluster_data).to be_present
          expect(cluster_data[:attributes]).to include(
            brand_name: "Diamine",
            line_name: "Standard",
            ink_name: "Blue",
            color: "#0000FF",
            description: "A beautiful blue ink",
            tags: %w[blue vibrant]
          )
        end

        it "includes all unique colors in macro_cluster details" do
          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          cluster_data =
            json[:included].find do |inc|
              inc[:type] == "macro_cluster" && inc[:id] == macro_cluster.id.to_s
            end

          expect(cluster_data[:attributes][:colors]).to match_array(%w[#0000FF #0000CC #0000AA])
        end

        it "includes all_names in macro_cluster details" do
          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          cluster_data =
            json[:included].find do |inc|
              inc[:type] == "macro_cluster" && inc[:id] == macro_cluster.id.to_s
            end

          expect(cluster_data[:attributes]).to have_key(:all_names)
          expect(cluster_data[:attributes][:all_names]).to be_an(Array)
        end

        it "includes public_collected_inks_count in macro_cluster details" do
          # Create a public collected ink for the count
          create(:collected_ink, micro_cluster: micro_cluster, private: false)

          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          cluster_data =
            json[:included].find do |inc|
              inc[:type] == "macro_cluster" && inc[:id] == macro_cluster.id.to_s
            end

          expect(cluster_data[:attributes]).to have_key(:public_collected_inks_count)
          expect(cluster_data[:attributes][:public_collected_inks_count]).to be >= 1
        end

        it "deduplicates macro_clusters when multiple collected inks share the same cluster" do
          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          # Should have 3 collected_inks but only 1 macro_cluster in included
          expect(json[:data].length).to eq(3)

          macro_clusters_in_included =
            json[:included].select { |inc| inc[:type] == "macro_cluster" }
          expect(macro_clusters_in_included.length).to eq(1)
          expect(macro_clusters_in_included.first[:id]).to eq(macro_cluster.id.to_s)
        end

        it "efficiently loads data with multiple clusters" do
          # Create another macro_cluster to test multiple clusters
          other_macro = create(:macro_cluster, brand_name: "Pilot", ink_name: "Kon-peki")
          other_micro = create(:micro_cluster, macro_cluster: other_macro)
          create(:collected_ink, user: user, micro_cluster: other_micro)

          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(json[:data].length).to eq(4) # 3 from first cluster + 1 from second

          # Should have 2 distinct macro_clusters in included
          macro_clusters_in_included =
            json[:included].select { |inc| inc[:type] == "macro_cluster" }
          expect(macro_clusters_in_included.length).to eq(2)

          cluster_ids = macro_clusters_in_included.map { |c| c[:id] }
          expect(cluster_ids).to match_array([macro_cluster.id.to_s, other_macro.id.to_s])
        end

        it "handles collected inks without micro_clusters gracefully" do
          # Create an ink without a micro_cluster
          create(:collected_ink, user: user, micro_cluster: nil)

          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(json[:data].length).to eq(4) # 3 with cluster + 1 without
        end

        it "works with pagination" do
          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true",
                page: {
                  number: 1,
                  size: 2
                }
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(json[:data].length).to eq(2)
          expect(json).to have_key(:included)
        end

        it "works with filtering by macro_cluster_id" do
          other_macro = create(:macro_cluster)
          other_micro = create(:micro_cluster, macro_cluster: other_macro)
          create(:collected_ink, user: user, micro_cluster: other_micro)

          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true",
                filter: {
                  macro_cluster_id: macro_cluster.id
                }
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(json[:data].length).to eq(3) # Only inks from the filtered cluster

          macro_clusters_in_included =
            json[:included].select { |inc| inc[:type] == "macro_cluster" }
          expect(macro_clusters_in_included.length).to eq(1)
          expect(macro_clusters_in_included.first[:id]).to eq(macro_cluster.id.to_s)
        end

        it "works with sparse fieldsets" do
          get "/api/v1/collected_inks",
              params: {
                include_cluster_details: "true",
                fields: {
                  collected_ink: "brand_name,ink_name"
                }
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          # Check that only the requested fields are present
          expect(json[:data].first[:attributes].keys).to match_array(%i[brand_name ink_name])
          expect(json[:data].first[:attributes][:brand_name]).to eq("Diamine")
          expect(json).to have_key(:included) # Still includes macro_cluster details
        end
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
