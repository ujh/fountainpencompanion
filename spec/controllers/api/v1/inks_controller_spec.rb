require "rails_helper"
require "apipie/rspec/response_validation_helper"

describe Api::V1::InksController do
  let(:user) { create(:user) }

  describe "#index" do
    it "requires authentication" do
      get :index, format: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      context "with schema validation" do
        auto_validate_rendered_views

        it "returns macro clusters" do
          macro_cluster = create(:macro_cluster)
          get :index, format: :json
          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response["data"].length).to eq(1)
          expect(json_response["data"][0]["id"].to_i).to eq(macro_cluster.id)
        end

        it "returns an empty list when there are no macro clusters" do
          get :index, format: :json
          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response["data"]).to be_empty
        end

        it "includes pagination metadata" do
          create(:macro_cluster)
          get :index, format: :json
          json_response = JSON.parse(response.body)
          pagination = json_response["meta"]["pagination"]
          expect(pagination).to include(
            "current_page" => 1,
            "total_pages" => 1,
            "total_count" => 1,
            "next_page" => nil,
            "prev_page" => nil
          )
        end

        it "paginates results" do
          create_list(:macro_cluster, 3)
          get :index, params: { page: { number: 1, size: 2 } }, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response["data"].length).to eq(2)
          pagination = json_response["meta"]["pagination"]
          expect(pagination["current_page"]).to eq(1)
          expect(pagination["total_pages"]).to eq(2)
          expect(pagination["total_count"]).to eq(3)
          expect(pagination["next_page"]).to eq(2)
          expect(pagination["prev_page"]).to be_nil
        end

        it "returns the second page of results" do
          create_list(:macro_cluster, 3)
          get :index, params: { page: { number: 2, size: 2 } }, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response["data"].length).to eq(1)
          pagination = json_response["meta"]["pagination"]
          expect(pagination["current_page"]).to eq(2)
          expect(pagination["prev_page"]).to eq(1)
          expect(pagination["next_page"]).to be_nil
        end

        it "returns default attributes for macro clusters" do
          create(
            :macro_cluster,
            brand_name: "Diamine",
            line_name: "Flower",
            ink_name: "Bluebell",
            color: "#1A2B3C"
          )
          get :index, format: :json
          json_response = JSON.parse(response.body)
          attributes = json_response["data"][0]["attributes"]
          expect(attributes["brand_name"]).to eq("Diamine")
          expect(attributes["line_name"]).to eq("Flower")
          expect(attributes["ink_name"]).to eq("Bluebell")
          expect(attributes["color"]).to eq("#1A2B3C")
        end
      end

      it "limits returned fields when fields param is specified" do
        create(:macro_cluster, brand_name: "Diamine", ink_name: "Bluebell")
        get :index, params: { fields: { macro_cluster: "brand_name,ink_name" } }, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        attributes = json_response["data"][0]["attributes"]
        expect(attributes.keys).to match_array(%w[brand_name ink_name])
      end

      context "filtering by ink_name" do
        it "returns matching macro clusters" do
          macro_cluster = create(:macro_cluster, ink_name: "Bluebell")
          micro_cluster =
            create(:micro_cluster, macro_cluster: macro_cluster, simplified_ink_name: "bluebell")
          3.times do
            create(
              :collected_ink,
              ink_name: "Bluebell",
              micro_cluster: micro_cluster,
              private: false
            )
          end
          non_matching = create(:macro_cluster, ink_name: "Oxblood")
          get :index,
              params: {
                filter: {
                  ink_name: "Bluebell"
                },
                fields: {
                  macro_cluster: "ink_name"
                }
              },
              format: :json
          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          ids = json_response["data"].map { |d| d["id"].to_i }
          expect(ids).to include(macro_cluster.id)
          expect(ids).not_to include(non_matching.id)
        end
      end

      context "filtering by line_name" do
        it "returns matching macro clusters" do
          macro_cluster = create(:macro_cluster, line_name: "Flower")
          micro_cluster =
            create(:micro_cluster, macro_cluster: macro_cluster, simplified_line_name: "flower")
          3.times do
            create(
              :collected_ink,
              line_name: "Flower",
              micro_cluster: micro_cluster,
              private: false
            )
          end
          non_matching = create(:macro_cluster, line_name: "Standard")
          get :index,
              params: {
                filter: {
                  line_name: "Flower"
                },
                fields: {
                  macro_cluster: "line_name"
                }
              },
              format: :json
          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          ids = json_response["data"].map { |d| d["id"].to_i }
          expect(ids).to include(macro_cluster.id)
          expect(ids).not_to include(non_matching.id)
        end
      end

      context "filtering by ink_name with brand_name" do
        it "narrows results by brand" do
          macro_cluster = create(:macro_cluster, brand_name: "Diamine", ink_name: "Bluebell")
          micro_cluster =
            create(
              :micro_cluster,
              macro_cluster: macro_cluster,
              simplified_ink_name: "bluebell",
              simplified_brand_name: "diamine"
            )
          3.times do
            create(
              :collected_ink,
              brand_name: "Diamine",
              ink_name: "Bluebell",
              micro_cluster: micro_cluster,
              private: false
            )
          end
          other_brand_cluster = create(:macro_cluster, brand_name: "Pilot", ink_name: "Bluebell")
          other_micro =
            create(
              :micro_cluster,
              macro_cluster: other_brand_cluster,
              simplified_ink_name: "bluebell",
              simplified_brand_name: "pilot"
            )
          3.times do
            create(
              :collected_ink,
              brand_name: "Pilot",
              ink_name: "Bluebell",
              micro_cluster: other_micro,
              private: false
            )
          end
          get :index,
              params: {
                filter: {
                  ink_name: "Bluebell",
                  brand_name: "Diamine"
                },
                fields: {
                  macro_cluster: "ink_name"
                }
              },
              format: :json
          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          ids = json_response["data"].map { |d| d["id"].to_i }
          expect(ids).to include(macro_cluster.id)
          expect(ids).not_to include(other_brand_cluster.id)
        end
      end

      context "filtering by line_name with brand_name" do
        it "narrows results by brand" do
          macro_cluster = create(:macro_cluster, brand_name: "Diamine", line_name: "Flower")
          micro_cluster =
            create(
              :micro_cluster,
              macro_cluster: macro_cluster,
              simplified_line_name: "flower",
              simplified_brand_name: "diamine"
            )
          3.times do
            create(
              :collected_ink,
              brand_name: "Diamine",
              line_name: "Flower",
              micro_cluster: micro_cluster,
              private: false
            )
          end
          other_brand_cluster = create(:macro_cluster, brand_name: "Pilot", line_name: "Flower")
          other_micro =
            create(
              :micro_cluster,
              macro_cluster: other_brand_cluster,
              simplified_line_name: "flower",
              simplified_brand_name: "pilot"
            )
          3.times do
            create(
              :collected_ink,
              brand_name: "Pilot",
              line_name: "Flower",
              micro_cluster: other_micro,
              private: false
            )
          end
          get :index,
              params: {
                filter: {
                  line_name: "Flower",
                  brand_name: "Diamine"
                },
                fields: {
                  macro_cluster: "line_name"
                }
              },
              format: :json
          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          ids = json_response["data"].map { |d| d["id"].to_i }
          expect(ids).to include(macro_cluster.id)
          expect(ids).not_to include(other_brand_cluster.id)
        end
      end
    end
  end
end
