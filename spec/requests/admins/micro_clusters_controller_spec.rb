require "rails_helper"

describe Admins::MicroClustersController do
  let(:admin) { create(:user, :admin) }

  describe "#index" do
    it "requires authentication" do
      get "/admins/micro_clusters"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders the json" do
        micro_cluster = create(:micro_cluster)
        ci1 = create(:collected_ink, micro_cluster: micro_cluster)
        ci2 = create(:collected_ink, micro_cluster: micro_cluster)
        get "/admins/micro_clusters.json"
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to match(
          {
            "data" => [
              {
                "id" => micro_cluster.id.to_s,
                "type" => "micro_cluster",
                "attributes" => {
                  "simplified_brand_name" =>
                    micro_cluster.simplified_brand_name,
                  "simplified_line_name" => micro_cluster.simplified_line_name,
                  "simplified_ink_name" => micro_cluster.simplified_ink_name
                },
                "relationships" => {
                  "macro_cluster" => {
                    "data" => nil
                  },
                  "collected_inks" => {
                    "data" =>
                      match_array(
                        [
                          { "id" => ci1.id.to_s, "type" => "collected_ink" },
                          { "id" => ci2.id.to_s, "type" => "collected_ink" }
                        ]
                      )
                  }
                }
              }
            ],
            "included" =>
              match_array(
                [
                  {
                    "id" => ci1.id.to_s,
                    "type" => "collected_ink",
                    "attributes" => {
                      "brand_name" => ci1.brand_name,
                      "line_name" => ci1.line_name,
                      "ink_name" => ci1.ink_name,
                      "maker" => ci1.maker,
                      "color" => ci1.color
                    },
                    "relationships" => {
                      "micro_cluster" => {
                        "data" => {
                          "id" => micro_cluster.id.to_s,
                          "type" => "micro_cluster"
                        }
                      }
                    }
                  },
                  {
                    "id" => ci2.id.to_s,
                    "type" => "collected_ink",
                    "attributes" => {
                      "brand_name" => ci2.brand_name,
                      "line_name" => ci2.line_name,
                      "ink_name" => ci2.ink_name,
                      "maker" => ci2.maker,
                      "color" => ci2.color
                    },
                    "relationships" => {
                      "micro_cluster" => {
                        "data" => {
                          "id" => micro_cluster.id.to_s,
                          "type" => "micro_cluster"
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
          }
        )
      end
    end
  end

  describe "#update" do
    let(:micro_cluster) { create(:micro_cluster) }

    it "requires authentication" do
      put "/admins/micro_clusters/#{micro_cluster.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "updates the macro cluster id" do
        expect(micro_cluster.macro_cluster).to be(nil)
        macro_cluster = create(:macro_cluster)
        put "/admins/micro_clusters/#{micro_cluster.id}",
            params: {
              "data" => {
                "id" => micro_cluster.id.to_s,
                "type" => "micro_cluster",
                "attributes" => {
                  "macro_cluster_id" => macro_cluster.id
                }
              }
            }
        expect(response).to be_successful
        expect(micro_cluster.reload.macro_cluster).to eq(macro_cluster)
      end
    end
  end

  describe "#unassign" do
    let!(:macro_cluster) { create(:macro_cluster) }
    let!(:micro_cluster) do
      create(:micro_cluster, macro_cluster: macro_cluster)
    end

    before(:each) { sign_in(admin) }

    it "unassigns it from the macro cluster" do
      expect do
        delete "/admins/micro_clusters/#{micro_cluster.id}/unassign"
        expect(response).to be_successful
      end.to change { micro_cluster.reload.macro_cluster_id }.from(
        macro_cluster.id
      ).to(nil)
    end

    it "schedules a recalculation of the macro cluster data" do
      expect do
        delete "/admins/micro_clusters/#{micro_cluster.id}/unassign"
        expect(response).to be_successful
      end.to change { UpdateMacroCluster.jobs.count }.from(0).to(1)
      job = UpdateMacroCluster.jobs.first
      expect(job["args"]).to eq([macro_cluster.id])
    end
  end
end
