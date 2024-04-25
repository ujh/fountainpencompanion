require "rails_helper"

describe Admins::Pens::ModelVariantsController do
  let(:admin) { create(:user, :admin) }

  describe "#index" do
    it "requires authentication" do
      get "/admins/pens/model_variants"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders the json" do
        model_variant = create(:pens_model_variant)
        pens_micro_cluster = create(:pens_micro_cluster, model_variant:)
        collected_pen = create(:collected_pen, pens_micro_cluster:)
        get "/admins/pens/model_variants.json"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to match(
          "data" => [
            {
              "id" => model_variant.id.to_s,
              "type" => "pens_model_variant",
              "attributes" => {
                "brand" => "Brand",
                "model" => "Model",
                "color" => "",
                "material" => "",
                "trim_color" => "",
                "filling_system" => ""
              },
              "relationships" => {
                "micro_clusters" => {
                  "data" => [
                    {
                      "id" => pens_micro_cluster.id.to_s,
                      "type" => "pens_micro_cluster"
                    }
                  ]
                }
              }
            }
          ],
          "included" =>
            match_array(
              [
                {
                  "id" => collected_pen.id.to_s,
                  "type" => "collected_pen",
                  "attributes" => {
                    "brand" => "Wing Sung",
                    "model" => "618",
                    "color" => "black",
                    "material" => "plastic",
                    "trim_color" => "gold",
                    "filling_system" => "piston filler"
                  },
                  "relationships" => {
                    "pens_micro_cluster" => {
                      "data" => {
                        "id" => pens_micro_cluster.id.to_s,
                        "type" => "pens_micro_cluster"
                      }
                    }
                  }
                },
                {
                  "id" => pens_micro_cluster.id.to_s,
                  "type" => "pens_micro_cluster",
                  "attributes" => {
                  },
                  "relationships" => {
                    "model_variant" => {
                      "data" => {
                        "id" => model_variant.id.to_s,
                        "type" => "pens_model_variant"
                      }
                    },
                    "collected_pens" => {
                      "data" => [
                        {
                          "id" => collected_pen.id.to_s,
                          "type" => "collected_pen"
                        }
                      ]
                    }
                  }
                }
              ]
            ),
          "meta" => {
            "pagination" => {
              "total_pages" => 1,
              "current_page" => 1,
              "next_page" => nil,
              "prev_page" => nil
            }
          }
        )
      end
    end
  end

  describe "#show" do
    let(:model_variant) { create(:pens_model_variant) }

    it "requires authentication" do
      get "/admins/pens/model_variants/#{model_variant.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders the json" do
        get "/admins/pens/model_variants/#{model_variant.id}"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to match(
          "data" => {
            "id" => model_variant.id.to_s,
            "type" => "pens_model_variant",
            "attributes" => {
              "brand" => "Brand",
              "model" => "Model",
              "color" => "",
              "material" => "",
              "trim_color" => "",
              "filling_system" => ""
            },
            "relationships" => {
              "micro_clusters" => {
                "data" => []
              }
            }
          },
          "included" => []
        )
      end
    end
  end

  describe "#create" do
    it "requires authentication" do
      post "/admins/pens/model_variants"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "creates the model variant" do
        expect do
          post "/admins/pens/model_variants",
               params: {
                 data: {
                   type: "pens_model_variant",
                   attributes: {
                     brand: "Brand",
                     model: "Model"
                   }
                 }
               }
          expect(response).to be_successful
          json = JSON.parse(response.body)
          expect(json).to match(
            "data" => {
              "id" => Pens::ModelVariant.last.id.to_s,
              "type" => "pens_model_variant",
              "attributes" => {
                "brand" => "Brand",
                "model" => "Model",
                "color" => "",
                "material" => "",
                "trim_color" => "",
                "filling_system" => ""
              },
              "relationships" => {
                "micro_clusters" => {
                  "data" => []
                }
              }
            },
            "included" => []
          )
        end.to change(Pens::ModelVariant, :count).by(1)
      end
    end
  end
end
