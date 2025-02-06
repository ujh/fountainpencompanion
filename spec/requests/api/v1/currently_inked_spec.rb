require "rails_helper"

describe Api::V1::CurrentlyInkedController do
  describe "GET /index" do
    it "requires authentication" do
      get "/api/v1/currently_inked", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "returns all currently inked entries" do
        create(:currently_inked, user: user)
        create(:currently_inked, user: user)

        get "/api/v1/currently_inked", headers: { "ACCEPT" => "application/json" }
        expect(json).to include(
          data: [hash_including(type: "currently_inked"), hash_including(type: "currently_inked")]
        )
      end

      it "has the correct default fields and includes" do
        ci = create(:currently_inked, user: user)
        macro_cluster = create(:macro_cluster)
        micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
        ci.collected_ink.update!(micro_cluster: micro_cluster)

        get "/api/v1/currently_inked", headers: { "ACCEPT" => "application/json" }

        expect(json).to include(
          data: [
            hash_including(
              attributes: {
                inked_on: anything,
                archived_on: anything,
                comment: anything,
                last_used_on: anything,
                daily_usage: anything,
                refillable: anything,
                unarchivable: anything,
                archived: anything,
                ink_name: anything,
                pen_name: anything,
                used_today: anything
              },
              relationships: {
                collected_ink: anything,
                collected_pen: anything
              }
            )
          ],
          included:
            match_array(
              [
                hash_including(
                  type: "micro_cluster",
                  attributes: {
                  },
                  relationships: {
                    macro_cluster: anything
                  }
                ),
                hash_including(
                  type: "collected_ink",
                  attributes: {
                    brand_name: anything,
                    line_name: anything,
                    ink_name: anything,
                    color: anything,
                    archived: anything
                  }
                ),
                hash_including(
                  type: "collected_pen",
                  attributes: {
                    brand: anything,
                    model: anything,
                    nib: anything,
                    color: anything,
                    model_variant_id: anything
                  }
                )
              ]
            )
        )
      end

      it "allows specifying the fields to return" do
        ci = create(:currently_inked, user: user)
        macro_cluster = create(:macro_cluster)
        micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
        ci.collected_ink.update!(micro_cluster: micro_cluster)

        get "/api/v1/currently_inked",
            params: {
              fields: {
                currently_inked: "comment",
                collected_ink: "brand_name",
                collected_pen: "brand"
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(
          data: [hash_including(attributes: { comment: anything }, relationships: {})],
          included:
            match_array(
              [
                hash_including(
                  type: "micro_cluster",
                  attributes: {
                  },
                  relationships: {
                    macro_cluster: anything
                  }
                ),
                hash_including(type: "collected_ink", attributes: { brand_name: anything }),
                hash_including(type: "collected_pen", attributes: { brand: anything })
              ]
            )
        )
      end

      it "supports pagination" do
        create(:currently_inked, user: user)
        create(:currently_inked, user: user)
        create(:currently_inked, user: user)

        get "/api/v1/currently_inked",
            params: {
              page: {
                number: 2,
                size: 1
              }
            },
            headers: {
              "ACCEPT" => "application/json"
            }

        expect(json).to include(
          data: [hash_including(:attributes)],
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

      it "can return only archived entries" do
        archived = create(:currently_inked, user: user, archived_on: 1.day.ago)
        active = create(:currently_inked, user: user)

        get "/api/v1/currently_inked",
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
        archived = create(:currently_inked, user: user, archived_on: 1.day.ago)
        active = create(:currently_inked, user: user)

        get "/api/v1/currently_inked",
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
