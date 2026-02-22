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
            create(:micro_cluster, macro_cluster: create(:macro_cluster, ink_name: "Aventurine"))
        )

        create_list(
          :collected_ink,
          3,
          ink_name: "Mandarin",
          micro_cluster:
            create(:micro_cluster, macro_cluster: create(:macro_cluster, ink_name: "Mandarin"))
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
            create(:micro_cluster, macro_cluster: create(:macro_cluster, ink_name: "Aventurine"))
        )

        create_list(
          :collected_ink,
          3,
          ink_name: "Mandarin",
          micro_cluster:
            create(:micro_cluster, macro_cluster: create(:macro_cluster, ink_name: "Mandarin"))
        )

        get "/api/v1/inks", params: { term: "man" }, headers: { "ACCEPT" => "application/json" }
        expect(json).to match(data: [hash_including(attributes: { ink_name: "Mandarin" })])
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
              macro_cluster: create(:macro_cluster, brand_name: "Pelikan", ink_name: "Mandarin")
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
              macro_cluster: create(:macro_cluster, brand_name: "Other", ink_name: "Manda")
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
        expect(json).to match(data: [hash_including(attributes: { ink_name: "Mandarin" })])
      end
    end
  end

  describe "GET /show" do
    it "requires authentication" do
      macro_cluster = create(:macro_cluster, ink_name: "Test Ink")
      get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      before(:each) { sign_in(user) }

      it "returns a 404 for non-existent ink" do
        get "/api/v1/inks/99999", headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:not_found)
      end

      it "returns basic ink information" do
        macro_cluster =
          create(
            :macro_cluster,
            brand_name: "Pelikan",
            line_name: "Edelstein",
            ink_name: "Blue",
            color: "#0000FF"
          )

        get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json).to include(
          data:
            hash_including(
              id: macro_cluster.id.to_s,
              type: "macro_cluster",
              attributes:
                hash_including(
                  brand_name: "Pelikan",
                  line_name: "Edelstein",
                  ink_name: "Blue",
                  color: "#0000FF"
                )
            )
        )
      end

      it "includes description in the response" do
        macro_cluster =
          create(:macro_cluster, ink_name: "Blue", description: "A beautiful blue ink")

        get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }

        expect(json[:data][:attributes]).to include(description: "A beautiful blue ink")
      end

      it "includes public collected inks count" do
        macro_cluster = create(:macro_cluster, ink_name: "Blue")
        micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
        create(:collected_ink, micro_cluster: micro_cluster, private: false)
        create(:collected_ink, micro_cluster: micro_cluster, private: false)
        create(:collected_ink, micro_cluster: micro_cluster, private: true)

        get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }

        expect(json[:data][:attributes][:public_collected_inks_count]).to eq(2)
      end

      it "includes all unique colors reported for the ink" do
        macro_cluster = create(:macro_cluster, ink_name: "Blue")
        micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
        create(:collected_ink, micro_cluster: micro_cluster, color: "#0000FF")
        create(:collected_ink, micro_cluster: micro_cluster, color: "#0000CC")
        create(:collected_ink, micro_cluster: micro_cluster, color: "#0000FF")
        create(:collected_ink, micro_cluster: micro_cluster, color: "")

        get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }

        expect(json[:data][:attributes][:colors]).to match_array(%w[#0000FF #0000CC])
      end

      it "includes tags associated with the ink" do
        macro_cluster = create(:macro_cluster, ink_name: "Blue", tags: %w[vibrant blue])

        get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }

        expect(json[:data][:attributes][:tags]).to match_array(%w[vibrant blue])
      end

      it "includes all alternative names for the ink" do
        macro_cluster = create(:macro_cluster, ink_name: "Blue")
        micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)

        create(
          :collected_ink,
          micro_cluster: micro_cluster,
          brand_name: "Pelikan",
          line_name: "Edelstein",
          ink_name: "Blue"
        )
        create(
          :collected_ink,
          micro_cluster: micro_cluster,
          brand_name: "Pelikan",
          line_name: "Edelstein",
          ink_name: "Blue"
        )

        get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }

        all_names = json[:data][:attributes][:all_names]
        expect(all_names).to be_an(Array)
        expect(all_names.length).to be >= 1
        expect(all_names[0]).to include(:brand_name, :line_name, :ink_name, :collected_inks_count)
      end

      it "includes approved ink reviews" do
        macro_cluster = create(:macro_cluster, ink_name: "Blue")
        review1 =
          create(
            :ink_review,
            macro_cluster: macro_cluster,
            title: "Great Blue",
            approved_at: Time.zone.now
          )
        review2 =
          create(
            :ink_review,
            macro_cluster: macro_cluster,
            title: "Another Blue",
            approved_at: Time.zone.now
          )
        rejected_review =
          create(
            :ink_review,
            macro_cluster: macro_cluster,
            title: "Rejected",
            rejected_at: Time.zone.now
          )

        get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }

        expect(json[:data][:relationships][:approved_ink_reviews][:data]).to be_an(Array)
        expect(json[:data][:relationships][:approved_ink_reviews][:data].length).to eq(2)
      end

      it "does not include reviews relationship when there are no approved reviews" do
        macro_cluster = create(:macro_cluster, ink_name: "Blue")

        get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }

        relationships = json[:data].fetch(:relationships, {})
        reviews_relationship = relationships.fetch(:approved_ink_reviews, { data: [] })
        expect(reviews_relationship[:data]).to eq([])
      end

      it "includes review details in included resources" do
        macro_cluster = create(:macro_cluster, ink_name: "Blue")
        review =
          create(
            :ink_review,
            macro_cluster: macro_cluster,
            title: "Great Blue",
            approved_at: Time.zone.now,
            author: "Test Author",
            description: "Amazing ink!"
          )

        get "/api/v1/inks/#{macro_cluster.id}", headers: { "ACCEPT" => "application/json" }

        reviews_data = json[:included]&.select { |item| item[:type] == "ink_review" } || []
        expect(reviews_data).not_to be_empty
        expect(reviews_data[0][:attributes]).to include(
          title: "Great Blue",
          author: "Test Author",
          description: "Amazing ink!"
        )
      end
    end
  end
end
