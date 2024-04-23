require "rails_helper"

describe Admins::Pens::MicroClustersController do
  let(:admin) { create(:user, :admin) }

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
              "simplified_color" => pens_cluster.simplified_color,
              "simplified_material" => pens_cluster.simplified_material,
              "simplified_trim_color" => pens_cluster.simplified_trim_color,
              "simplified_filling_system" =>
                pens_cluster.simplified_filling_system
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
