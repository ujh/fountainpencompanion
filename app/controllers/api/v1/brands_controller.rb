class Api::V1::BrandsController < Api::V1::BaseController
  api :GET, "/api/v1/brands", "Retrieve the global list of ink brands"
  param :term, String, desc: "Search term for brand name", required: false
  returns code: 200, desc: "List of brands" do
    property :data, array_of: Hash, desc: "Array of brand objects" do
      property :id, String, desc: "Brand ID"
      property :type, String, desc: "Resource type (brand)"
      property :attributes, Hash, desc: "Brand attributes" do
        property :name, String, desc: "Brand name"
      end
      property :relationships,
               Hash,
               desc: "Related resources",
               required: false,
               default_value: {
               } do
        property :macro_clusters,
                 Hash,
                 desc: "Related macro clusters",
                 required: false,
                 default_value: nil do
          property :data, array_of: Hash, desc: "Array of related macro cluster references" do
            property :id, String, desc: "Macro cluster ID"
            property :type, String, desc: "Resource type (macro_cluster)"
          end
        end
      end
    end
  end
  def index
    render json: serializer.serializable_hash.to_json
  end

  api :GET, "/api/v1/brands/:id", "Retrieve details for a specific ink brand"
  param :id, String, desc: "Brand ID", required: true
  returns code: 200, desc: "Brand details" do
    property :data, Hash, desc: "Brand object" do
      property :id, String, desc: "Brand ID"
      property :type, String, desc: "Resource type (brand)"
      property :attributes, Hash, desc: "Brand attributes" do
        property :name, String, desc: "Brand name"
        property :description, String, desc: "Brand description"
        property :public_ink_count, Integer, desc: "Number of public inks for this brand"
      end
      property :relationships, Hash, desc: "Related resources" do
        property :macro_clusters, Hash, desc: "Related macro clusters" do
          property :data, array_of: Hash, desc: "Array of related macro cluster objects" do
            property :id, String, desc: "Macro cluster ID"
            property :type, String, desc: "Resource type (macro_cluster)"
          end
        end
      end
    end
    property :included,
             array_of: Hash,
             desc: "Included related resources (macro_clusters)",
             required: false,
             default_value: [] do
      property :id, String, desc: "Resource ID"
      property :type, String, desc: "Resource type"
      property :attributes, Hash, desc: "Resource attributes" do
        property :brand_name, String, desc: "Brand name"
        property :line_name, String, desc: "Line name"
        property :ink_name, String, desc: "Ink name"
        property :color, String, desc: "Hex color code"
        property :description, String, desc: "Description"
        property :tags, array_of: String, desc: "Tags"
        property :public_collected_inks_count, Integer, desc: "Number of public collected inks"
        property :colors, array_of: String, desc: "Unique colors from collected inks"
        property :all_names, array_of: Hash, desc: "All name variants for this ink" do
          property :brand_name, String, desc: "Brand name"
          property :line_name, String, desc: "Line name"
          property :ink_name, String, desc: "Ink name"
          property :collected_inks_count, Integer, desc: "Number of collected inks with this name"
        end
      end
      property :relationships,
               Hash,
               desc: "Resource relationships",
               required: false,
               default_value: {
               } do
        property :micro_clusters,
                 Hash,
                 desc: "Related micro clusters",
                 required: false,
                 default_value: nil do
          property :data, array_of: Hash, desc: "Array of micro cluster references" do
            property :id, String, desc: "Micro cluster ID"
            property :type, String, desc: "Resource type (micro_cluster)"
          end
        end
      end
    end
  end
  def show
    render json: single_resource_serializer.serializable_hash.to_json
  end

  private

  def clusters
    BrandCluster.autocomplete_search(params[:term]).order(:name)
  end

  def serializer
    BrandClusterSerializer.new(clusters, { fields: { brand_cluster: [:name] } })
  end

  def cluster
    BrandCluster.includes(:collected_inks).find(params[:id])
  end

  def single_resource_serializer
    BrandClusterSerializer.new(cluster, { include: [:macro_clusters] })
  end
end
