require "rails_helper"

describe Admins::Pens::MicroClustersController do
  let(:admin) { create(:user, :admin) }

  describe "#index" do
    it "requires authentication" do
      get "/admins/pens/micro_clusters"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders the json" do
        pens_cluster = create(:pens_micro_cluster)
        cp1 = create(:collected_pen, pens_micro_cluster: pens_cluster)
        cp2 = create(:collected_pen, pens_micro_cluster: pens_cluster)
        get "/admins/pens/micro_clusters.json"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to match(
          "data" => [
            {
              "id" => pens_cluster.id.to_s,
              "type" => "pens_micro_cluster",
              "attributes" => {
                "simplified_brand" => pens_cluster.simplified_brand,
                "simplified_model" => pens_cluster.simplified_model,
                "simplified_color" => pens_cluster.simplified_color
              },
              "relationships" => {
                "collected_pens" => {
                  "data" =>
                    match_array(
                      [
                        { "id" => cp1.id.to_s, "type" => "collected_pen" },
                        { "id" => cp2.id.to_s, "type" => "collected_pen" }
                      ]
                    )
                },
                "model_variant" => {
                  "data" => nil
                }
              }
            }
          ],
          "included" =>
            match_array(
              [
                {
                  "id" => cp1.id.to_s,
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
                        "id" => pens_cluster.id.to_s,
                        "type" => "pens_micro_cluster"
                      }
                    }
                  }
                },
                {
                  "id" => cp2.id.to_s,
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
                        "id" => pens_cluster.id.to_s,
                        "type" => "pens_micro_cluster"
                      }
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
    let(:cluster) { create(:pens_micro_cluster) }

    it "requires authentication" do
      put "/admins/pens/micro_clusters/#{cluster.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "allows setting the ignored attribute" do
        expect do
          put "/admins/pens/micro_clusters/#{cluster.id}",
              params: {
                "data" => {
                  "id" => cluster.id.to_s,
                  "type" => "pens_micro_cluster",
                  "attributes" => {
                    "ignored" => true
                  }
                }
              }
        end.to change { cluster.reload.ignored }.from(false).to(true)
      end

      it "allows assigning the model variant" do
        model_variant = create(:pens_model_variant)

        expect do
          put "/admins/pens/micro_clusters/#{cluster.id}",
              params: {
                "data" => {
                  "id" => cluster.id.to_s,
                  "type" => "pens_micro_cluster",
                  "attributes" => {
                    "pens_model_variant_id" => model_variant.id
                  }
                }
              }
        end.to change { cluster.reload.model_variant }.from(nil).to(model_variant)
      end

      it "schedules a cluster update job" do
        expect do
          put "/admins/pens/micro_clusters/#{cluster.id}",
              params: {
                "data" => {
                  "id" => cluster.id.to_s,
                  "type" => "pens_micro_cluster",
                  "attributes" => {
                    "ignored" => true
                  }
                }
              }
        end.to change(Pens::UpdateMicroCluster.jobs, :length).by(1)

        job = Pens::UpdateMicroCluster.jobs.last
        expect(job["args"]).to eq([cluster.id])
      end
    end
  end

  describe "#unassign" do
    let(:cluster) { create(:pens_micro_cluster, model_variant:) }
    let(:model_variant) { create(:pens_model_variant) }

    it "requires authentication" do
      delete "/admins/pens/micro_clusters/#{cluster.id}/unassign"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "unassigns the micro cluster from the model variant" do
        expect do
          delete "/admins/pens/micro_clusters/#{cluster.id}/unassign"
          expect(response).to redirect_to(admins_pens_model_variants_path)
        end.to change { cluster.reload.model_variant }.from(model_variant).to(nil)
      end

      it "triggers the recalculation background job for the model variant" do
        expect do delete "/admins/pens/micro_clusters/#{cluster.id}/unassign" end.to change(
          Pens::UpdateModelVariant.jobs,
          :length
        ).by(1)
        job = Pens::UpdateModelVariant.jobs.last
        expect(job["args"].first).to eq(model_variant.id)
      end
    end
  end
end
