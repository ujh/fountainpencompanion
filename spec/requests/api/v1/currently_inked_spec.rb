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

      describe "include parameter" do
        let(:macro_cluster) { create(:macro_cluster) }
        let(:micro_cluster) { create(:micro_cluster, macro_cluster: macro_cluster) }
        let!(:own) do
          ci = create(:currently_inked, user: user)
          ci.collected_ink.update!(micro_cluster: micro_cluster)
          ci
        end
        let(:other_user) { create(:user) }
        let!(:other_ink) do
          create(
            :collected_ink,
            user: other_user,
            micro_cluster: micro_cluster,
            private: true,
            private_comment: "secret"
          )
        end
        let!(:other_ci) { create(:currently_inked, user: other_user, collected_ink: other_ink) }

        def included_of(type)
          Array(json[:included]).select { |r| r[:type] == type }
        end

        it "does not expose other users' records through nested includes" do
          get "/api/v1/currently_inked",
              params: {
                include:
                  "collected_ink,collected_ink.micro_cluster.collected_inks.currently_inkeds.collected_pen",
                fields: {
                  collected_ink: "brand_name,private,private_comment"
                }
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(included_of("collected_ink").map { |r| r[:id] }).to eq([own.collected_ink_id.to_s])
          expect(included_of("collected_pen")).to be_empty
          expect(included_of("currently_inked")).to be_empty
          expect(response.body).not_to include("secret")
        end

        it "ignores unknown includes but keeps the supported ones" do
          get "/api/v1/currently_inked",
              params: {
                include: "collected_ink,collected_ink.micro_cluster.collected_inks,bogus"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(json[:included].map { |r| r[:type] }).to eq(["collected_ink"])
        end

        it "supports including the macro cluster through the micro cluster" do
          get "/api/v1/currently_inked",
              params: {
                include:
                  "collected_ink,collected_ink.micro_cluster,collected_ink.micro_cluster.macro_cluster"
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(json[:included].map { |r| r[:type] }).to match_array(
            %w[collected_ink micro_cluster macro_cluster]
          )
          expect(included_of("macro_cluster").map { |r| r[:id] }).to eq([macro_cluster.id.to_s])
        end

        it "returns no included resources for a blank include" do
          get "/api/v1/currently_inked",
              params: {
                include: ""
              },
              headers: {
                "ACCEPT" => "application/json"
              }

          expect(response).to have_http_status(:ok)
          expect(json[:included]).to be_blank
        end
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
