require "rails_helper"

describe Admins::Pens::ModelsController do
  let(:admin) { create(:user, :admin) }

  describe "#index" do
    it "requires authentication" do
      get "/admins/pens/models"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      let!(:model) { create(:pens_model) }
      let!(:model_micro_cluster) { create(:pens_model_micro_cluster, model:) }
      let!(:model_variant) { create(:pens_model_variant, model_micro_cluster:) }

      it "renders the json" do
        get "/admins/pens/models.json"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to match(
          "data" => [
            {
              "id" => model.id.to_s,
              "type" => "pens_model",
              "attributes" => {
                "brand" => "Brand",
                "model" => model.model
              },
              "relationships" => {
                "model_micro_clusters" => {
                  "data" => [
                    { "id" => model_micro_cluster.id.to_s, "type" => "pens_model_micro_cluster" }
                  ]
                }
              }
            }
          ],
          "included" =>
            match_array(
              [
                {
                  "id" => model_variant.id.to_s,
                  "type" => "pens_model_variant",
                  "attributes" => {
                    "brand" => "Brand",
                    "model" => model_variant.model,
                    "color" => "",
                    "material" => "",
                    "trim_color" => "",
                    "filling_system" => ""
                  },
                  "relationships" => {
                    "micro_clusters" => {
                      "data" => []
                    },
                    "model_micro_cluster" => {
                      "data" => {
                        "id" => model_micro_cluster.id.to_s,
                        "type" => "pens_model_micro_cluster"
                      }
                    }
                  }
                },
                {
                  "id" => model_micro_cluster.id.to_s,
                  "type" => "pens_model_micro_cluster",
                  "attributes" => {
                  },
                  "relationships" => {
                    "model" => {
                      "data" => {
                        "id" => model.id.to_s,
                        "type" => "pens_model"
                      }
                    },
                    "model_variants" => {
                      "data" => [{ "id" => model_variant.id.to_s, "type" => "pens_model_variant" }]
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

      it "renders the HTML" do
        get "/admins/pens/models.html"
        expect(response).to be_successful
        expect(response.body).to include(model.model)
      end
    end
  end

  describe "#show" do
    let(:model) { create(:pens_model) }

    it "requires authentication" do
      get "/admins/pens/models/#{model.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders the json" do
        get "/admins/pens/models/#{model.id}"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to match(
          "data" => {
            "id" => model.id.to_s,
            "type" => "pens_model",
            "attributes" => {
              "brand" => "Brand",
              "model" => model.model
            },
            "relationships" => {
              "model_micro_clusters" => {
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
      post "/admins/pens/models"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "creates the model" do
        expect do
          post "/admins/pens/models",
               params: {
                 data: {
                   type: "pens_model",
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
              "id" => Pens::Model.last.id.to_s,
              "type" => "pens_model",
              "attributes" => {
                "brand" => "Brand",
                "model" => "Model"
              },
              "relationships" => {
                "model_micro_clusters" => {
                  "data" => []
                }
              }
            },
            "included" => []
          )
        end.to change(Pens::Model, :count).by(1)
      end
    end
  end

  describe "#destroy" do
    let!(:model) { create(:pens_model) }

    it "requires authentication" do
      delete "/admins/pens/models/#{model.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "deletes the model" do
        expect do
          delete "/admins/pens/models/#{model.id}"
          expect(response).to redirect_to(admins_pens_models_path)
        end.to change(Pens::Model, :count).by(-1)
      end

      it "unassigns all assigned model micro clusters" do
        model_micro_cluster = create(:pens_model_micro_cluster, model:)
        expect do delete "/admins/pens/models/#{model.id}" end.to change {
          model_micro_cluster.reload.model
        }.from(model).to(nil)
      end
    end
  end
end
