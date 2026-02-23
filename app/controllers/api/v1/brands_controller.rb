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
      property :relationships, Hash, desc: "Related resources", required: false
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
             required: false
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
