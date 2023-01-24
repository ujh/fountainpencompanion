require "rails_helper"

RSpec.describe "Api::V1::Inks", type: :request do
  describe "GET /index" do
    it "requires authentication" do
      get "/api/v1/inks", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "returns all inks in alphabetical order" do
        create_list(
          :collected_ink,
          3,
          ink_name: "Aventurine",
          micro_cluster:
            create(
              :micro_cluster,
              macro_cluster: create(:macro_cluster, ink_name: "Aventurine")
            )
        )

        create_list(
          :collected_ink,
          3,
          ink_name: "Mandarin",
          micro_cluster:
            create(
              :micro_cluster,
              macro_cluster: create(:macro_cluster, ink_name: "Mandarin")
            )
        )

        get "/api/v1/inks", headers: { "ACCEPT" => "application/json" }
        expect(json).to match(
          data: [
            hash_including(attributes: { ink_name: "Aventurine" }),
            hash_including(attributes: { ink_name: "Mandarin" })
          ]
        )
      end

      it "returns inks matching the search term" do
        create_list(
          :collected_ink,
          3,
          ink_name: "Aventurine",
          micro_cluster:
            create(
              :micro_cluster,
              macro_cluster: create(:macro_cluster, ink_name: "Aventurine")
            )
        )

        create_list(
          :collected_ink,
          3,
          ink_name: "Mandarin",
          micro_cluster:
            create(
              :micro_cluster,
              macro_cluster: create(:macro_cluster, ink_name: "Mandarin")
            )
        )

        get "/api/v1/inks",
            params: {
              term: "man"
            },
            headers: {
              "ACCEPT" => "application/json"
            }
        expect(json).to match(
          data: [hash_including(attributes: { ink_name: "Mandarin" })]
        )
      end

      it "returns inks from the correct brand if specified" do
        create_list(
          :collected_ink,
          3,
          brand_name: "Pelikan",
          ink_name: "Mandarin",
          micro_cluster:
            create(
              :micro_cluster,
              macro_cluster:
                create(
                  :macro_cluster,
                  brand_name: "Pelikan",
                  ink_name: "Mandarin"
                )
            )
        )

        create_list(
          :collected_ink,
          3,
          brand_name: "Other",
          ink_name: "Manda",
          micro_cluster:
            create(
              :micro_cluster,
              macro_cluster:
                create(:macro_cluster, brand_name: "Other", ink_name: "Manda")
            )
        )

        get "/api/v1/inks",
            params: {
              term: "man",
              brand_name: "peli"
            },
            headers: {
              "ACCEPT" => "application/json"
            }
        expect(json).to match(
          data: [hash_including(attributes: { ink_name: "Mandarin" })]
        )
      end
    end
  end
end
