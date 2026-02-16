require "rails_helper"

describe Admins::MacroClustersController do
  let(:admin) { create(:user, :admin) }

  describe "#index" do
    it "requires authentication" do
      get "/admins/macro_clusters"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders the clusters" do
        macro_cluster = create(:macro_cluster)
        micro_cluster = create(:micro_cluster, macro_cluster:)
        collected_ink = create(:collected_ink, micro_cluster:)
        all_names = macro_cluster.all_names
        all_name_elements =
          macro_cluster.all_names_as_elements.map do |ink|
            {
              "brand_name" => ink[:brand_name],
              "line_name" => ink[:line_name],
              "ink_name" => ink[:ink_name],
              "collected_inks_count" =>
                all_names
                  .find { |n| n.slice(:brand_name, :line_name, :ink_name) == ink }
                  &.collected_inks_count || 0
            }
          end
        colors = macro_cluster.collected_inks.pluck(:color).uniq.reject(&:blank?)
        get "/admins/macro_clusters.json"
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to match(
          {
            "data" => [
              {
                "id" => macro_cluster.id.to_s,
                "type" => "macro_cluster",
                "attributes" => {
                  "brand_name" => macro_cluster.brand_name,
                  "line_name" => macro_cluster.line_name,
                  "ink_name" => macro_cluster.ink_name,
                  "color" => macro_cluster.color,
                  "description" => macro_cluster.description,
                  "tags" => macro_cluster.tags,
                  "public_collected_inks_count" => macro_cluster.public_collected_inks_count,
                  "colors" => colors,
                  "all_names" => all_name_elements
                },
                "relationships" => {
                  "micro_clusters" => {
                    "data" => [{ "id" => micro_cluster.id.to_s, "type" => "micro_cluster" }]
                  }
                }
              }
            ],
            "included" =>
              match_array(
                [
                  {
                    "id" => micro_cluster.id.to_s,
                    "type" => "micro_cluster",
                    "attributes" => {
                    },
                    "relationships" => {
                      "macro_cluster" => {
                        "data" => {
                          "id" => macro_cluster.id.to_s,
                          "type" => "macro_cluster"
                        }
                      },
                      "collected_inks" => {
                        "data" => [{ "id" => collected_ink.id.to_s, "type" => "collected_ink" }]
                      }
                    }
                  },
                  {
                    "id" => collected_ink.id.to_s,
                    "type" => "collected_ink",
                    "attributes" => {
                      "brand_name" => collected_ink.brand_name,
                      "line_name" => collected_ink.line_name,
                      "ink_name" => collected_ink.ink_name,
                      "maker" => collected_ink.maker,
                      "color" => collected_ink.color
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

      it "includes micro clusters without collected inks" do
        macro_cluster = create(:macro_cluster)
        micro_cluster = create(:micro_cluster, macro_cluster:)
        get "/admins/macro_clusters.json"
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to match(
          {
            "data" => [
              {
                "id" => macro_cluster.id.to_s,
                "type" => "macro_cluster",
                "attributes" => {
                  "brand_name" => macro_cluster.brand_name,
                  "line_name" => macro_cluster.line_name,
                  "ink_name" => macro_cluster.ink_name,
                  "color" => macro_cluster.color,
                  "description" => macro_cluster.description,
                  "tags" => macro_cluster.tags,
                  "public_collected_inks_count" => macro_cluster.public_collected_inks_count,
                  "colors" => [],
                  "all_names" => []
                },
                "relationships" => {
                  "micro_clusters" => {
                    "data" => [{ "id" => micro_cluster.id.to_s, "type" => "micro_cluster" }]
                  }
                }
              }
            ],
            "included" =>
              match_array(
                [
                  {
                    "id" => micro_cluster.id.to_s,
                    "type" => "micro_cluster",
                    "attributes" => {
                    },
                    "relationships" => {
                      "macro_cluster" => {
                        "data" => {
                          "id" => macro_cluster.id.to_s,
                          "type" => "macro_cluster"
                        }
                      },
                      "collected_inks" => {
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
          }
        )
      end

      it "includes macro clusters without micro clusters" do
        macro_cluster = create(:macro_cluster)
        get "/admins/macro_clusters.json"
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq(
          "data" => [
            {
              "id" => macro_cluster.id.to_s,
              "type" => "macro_cluster",
              "attributes" => {
                "brand_name" => macro_cluster.brand_name,
                "line_name" => macro_cluster.line_name,
                "ink_name" => macro_cluster.ink_name,
                "color" => macro_cluster.color,
                "description" => macro_cluster.description,
                "tags" => macro_cluster.tags,
                "public_collected_inks_count" => macro_cluster.public_collected_inks_count,
                "colors" => [],
                "all_names" => []
              },
              "relationships" => {
                "micro_clusters" => {
                  "data" => []
                }
              }
            }
          ],
          "included" => [],
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

  describe "#create" do
    let(:params) do
      {
        data: {
          type: "macro_cluster",
          attributes: {
            brand_name: "brand_name",
            line_name: "line_name",
            ink_name: "ink_name",
            color: "#FFFFFF"
          }
        }
      }
    end

    it "requires authentication" do
      expect do
        post("/admins/macro_clusters", params:)
        expect(response).to redirect_to(new_user_session_path)
      end.to_not(change { MacroCluster.count })
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "creates the cluster" do
        expect do
          post("/admins/macro_clusters", params:)
          expect(response).to be_successful
        end.to change { MacroCluster.count }.by(1)
        cluster = MacroCluster.last
        expect(cluster.brand_name).to eq("brand_name")
        expect(cluster.line_name).to eq("line_name")
        expect(cluster.ink_name).to eq("ink_name")
        expect(cluster.color).to eq("#FFFFFF")
        expect(JSON.parse(response.body)).to match(
          {
            "data" => {
              "id" => cluster.id.to_s,
              "type" => "macro_cluster",
              "attributes" => {
                "brand_name" => "brand_name",
                "line_name" => "line_name",
                "ink_name" => "ink_name",
                "color" => "#FFFFFF",
                "description" => cluster.description,
                "tags" => cluster.tags,
                "public_collected_inks_count" => cluster.public_collected_inks_count,
                "colors" => [],
                "all_names" => []
              },
              "relationships" => {
                "micro_clusters" => {
                  "data" => []
                }
              }
            }
          }
        )
      end
    end
  end

  describe "#update" do
    let!(:macro_cluster) { create(:macro_cluster) }
    let(:params) do
      {
        data: {
          id: macro_cluster.id.to_s,
          type: "macro_cluster",
          attributes: {
            brand_name: "new brand_name",
            line_name: "new line_name",
            ink_name: "new ink_name",
            color: "#000000"
          }
        }
      }
    end

    it "requires authentication" do
      put("/admins/macro_clusters/#{macro_cluster.id}", params:)
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "updates the cluster" do
        put("/admins/macro_clusters/#{macro_cluster.id}", params:)
        expect(response).to be_successful
        macro_cluster.reload
        expect(macro_cluster.brand_name).to eq("new brand_name")
        expect(macro_cluster.line_name).to eq("new line_name")
        expect(macro_cluster.ink_name).to eq("new ink_name")
        expect(macro_cluster.color).to eq("#000000")
        expect(JSON.parse(response.body)).to match(
          {
            "data" => {
              "id" => macro_cluster.id.to_s,
              "type" => "macro_cluster",
              "attributes" => {
                "brand_name" => "new brand_name",
                "line_name" => "new line_name",
                "ink_name" => "new ink_name",
                "color" => "#000000",
                "description" => macro_cluster.description,
                "tags" => macro_cluster.tags,
                "public_collected_inks_count" => macro_cluster.public_collected_inks_count,
                "colors" => [],
                "all_names" => []
              },
              "relationships" => {
                "micro_clusters" => {
                  "data" => []
                }
              }
            }
          }
        )
      end
    end
  end

  describe "#destroy" do
    let!(:macro_cluster) { create(:macro_cluster) }

    it "requires authentication" do
      expect do
        delete "/admins/macro_clusters/#{macro_cluster.id}"
        expect(response).to redirect_to(new_user_session_path)
      end.to_not(change { MacroCluster.count })
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "deletes the cluster" do
        expect do
          delete "/admins/macro_clusters/#{macro_cluster.id}"
          expect(response).to be_successful
        end.to change { MacroCluster.count }.by(-1)
      end
    end
  end
end
