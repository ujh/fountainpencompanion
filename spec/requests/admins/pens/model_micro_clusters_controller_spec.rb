require "rails_helper"

describe Admins::Pens::ModelMicroClustersController do
  let(:admin) { create(:user, :admin) }

  describe "#index" do
    it "requires authentication" do
      get "/admins/pens/model_micro_clusters"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders the json" do
        model_micro_cluster = create(:pens_model_micro_cluster)
        mv1 = create(:pens_model_variant, model_micro_cluster:)
        mv2 = create(:pens_model_variant, model_micro_cluster:)
        get "/admins/pens/model_micro_clusters.json"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to match(
          "data" => [
            {
              "id" => model_micro_cluster.id.to_s,
              "type" => "pens_model_micro_cluster",
              "attributes" => {
                "simplified_brand" => model_micro_cluster.simplified_brand,
                "simplified_model" => model_micro_cluster.simplified_model
              },
              "relationships" => {
                "model_variants" => {
                  "data" =>
                    match_array(
                      [
                        { "id" => mv1.id.to_s, "type" => "pens_model_variant" },
                        { "id" => mv2.id.to_s, "type" => "pens_model_variant" }
                      ]
                    )
                },
                "model" => {
                  "data" => nil
                }
              }
            }
          ],
          "included" =>
            match_array(
              [
                {
                  "id" => mv1.id.to_s,
                  "type" => "pens_model_variant",
                  "attributes" => {
                    "brand" => mv1.brand,
                    "model" => mv1.model,
                    "color" => "",
                    "material" => "",
                    "trim_color" => "",
                    "filling_system" => ""
                  },
                  "relationships" => {
                    "model_micro_cluster" => {
                      "data" => {
                        "id" => model_micro_cluster.id.to_s,
                        "type" => "pens_model_micro_cluster"
                      }
                    },
                    "micro_clusters" => {
                      "data" => []
                    }
                  }
                },
                {
                  "id" => mv2.id.to_s,
                  "type" => "pens_model_variant",
                  "attributes" => {
                    "brand" => mv2.brand,
                    "model" => mv2.model,
                    "color" => "",
                    "material" => "",
                    "trim_color" => "",
                    "filling_system" => ""
                  },
                  "relationships" => {
                    "model_micro_cluster" => {
                      "data" => {
                        "id" => model_micro_cluster.id.to_s,
                        "type" => "pens_model_micro_cluster"
                      }
                    },
                    "micro_clusters" => {
                      "data" => []
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

  describe "#update" do
    let(:cluster) { create(:pens_model_micro_cluster) }

    it "requires authentication" do
      put "/admins/pens/model_micro_clusters/#{cluster.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "allows setting the ignored attribute" do
        expect do
          put "/admins/pens/model_micro_clusters/#{cluster.id}",
              params: {
                "data" => {
                  "id" => cluster.id.to_s,
                  "type" => "pens_model_micro_cluster",
                  "attributes" => {
                    "ignored" => true
                  }
                }
              }
        end.to change { cluster.reload.ignored }.from(false).to(true)
      end

      it "allows assigning the model" do
        model = create(:pens_model)

        expect do
          put "/admins/pens/model_micro_clusters/#{cluster.id}",
              params: {
                "data" => {
                  "id" => cluster.id.to_s,
                  "type" => "pens_model_micro_cluster",
                  "attributes" => {
                    "pens_model_id" => model.id
                  }
                }
              }
        end.to change { cluster.reload.model }.from(nil).to(model)
      end

      it "schedules a cluster update job" do
        expect do
          put "/admins/pens/model_micro_clusters/#{cluster.id}",
              params: {
                "data" => {
                  "id" => cluster.id.to_s,
                  "type" => "pens_model_micro_cluster",
                  "attributes" => {
                    "ignored" => true
                  }
                }
              }
        end.to change(Pens::UpdateModelMicroCluster.jobs, :length).by(1)

        job = Pens::UpdateModelMicroCluster.jobs.last
        expect(job["args"]).to eq([cluster.id])
      end
    end
  end

  describe "#unassign" do
    let(:cluster) { create(:pens_model_micro_cluster, model:) }
    let(:model) { create(:pens_model) }

    it "requires authentication" do
      delete "/admins/pens/model_micro_clusters/#{cluster.id}/unassign"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "unassigns the model micro cluster from the model" do
        expect do
          delete "/admins/pens/model_micro_clusters/#{cluster.id}/unassign"
          expect(response).to redirect_to(admins_pens_models_path)
        end.to change { cluster.reload.model }.from(model).to(nil)
      end

      it "triggers the recalculation background job for the model" do
        expect do
          delete "/admins/pens/model_micro_clusters/#{cluster.id}/unassign"
        end.to change(Pens::UpdateModel.jobs, :length).by(1)
        job = Pens::UpdateModel.jobs.last
        expect(job["args"].first).to eq(model.id)
      end
    end
  end
end
