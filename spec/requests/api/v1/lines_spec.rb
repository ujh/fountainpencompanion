require "rails_helper"

RSpec.describe "Api::V1::Lines", type: :request do
  describe "GET /index" do
    it "requires authentication" do
      get "/api/v1/lines", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "returns all lines in alphabetical order" do
        create_list(
          :collected_ink,
          3,
          line_name: "Edelstein",
          micro_cluster:
            create(:micro_cluster, macro_cluster: create(:macro_cluster, line_name: "Edelstein"))
        )

        create_list(
          :collected_ink,
          3,
          line_name: "Iroshizuku",
          micro_cluster:
            create(:micro_cluster, macro_cluster: create(:macro_cluster, line_name: "Iroshizuku"))
        )

        get "/api/v1/lines", headers: { "ACCEPT" => "application/json" }
        expect(json).to match(
          data: [
            hash_including(attributes: { line_name: "Edelstein" }),
            hash_including(attributes: { line_name: "Iroshizuku" })
          ]
        )
      end

      it "returns lines matching the search term" do
        create_list(
          :collected_ink,
          3,
          line_name: "Edelstein",
          micro_cluster:
            create(:micro_cluster, macro_cluster: create(:macro_cluster, line_name: "Edelstein"))
        )

        create_list(
          :collected_ink,
          3,
          line_name: "Iroshizuku",
          micro_cluster:
            create(:micro_cluster, macro_cluster: create(:macro_cluster, line_name: "Iroshizuku"))
        )

        get "/api/v1/lines", params: { term: "iro" }, headers: { "ACCEPT" => "application/json" }
        expect(json).to match(data: [hash_including(attributes: { line_name: "Iroshizuku" })])
      end

      it "returns lines from the correct brand if specified" do
        create_list(
          :collected_ink,
          3,
          brand_name: "Pelikan",
          line_name: "Edelstein",
          micro_cluster:
            create(
              :micro_cluster,
              macro_cluster: create(:macro_cluster, brand_name: "Pelikan", line_name: "Edelstein")
            )
        )

        create_list(
          :collected_ink,
          3,
          brand_name: "Other",
          line_name: "Stein",
          micro_cluster:
            create(
              :micro_cluster,
              macro_cluster: create(:macro_cluster, brand_name: "Other", line_name: "Stein")
            )
        )

        get "/api/v1/lines",
            params: {
              term: "stein",
              brand_name: "peli"
            },
            headers: {
              "ACCEPT" => "application/json"
            }
        expect(json).to match(data: [hash_including(attributes: { line_name: "Edelstein" })])
      end
    end
  end
end
