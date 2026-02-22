class Api::V1::InksController < Api::V1::BaseController
  resource_description do
    short "Inks. Autocomplete search for inks"
    formats ["json"]
    description "Endpoints for searching and retrieving available inks."
  end

  api :GET, "/api/v1/inks", "Search for inks with autocomplete"
  param :term, String, desc: "Search term to filter inks by name", required: false
  param :brand_name,
        String,
        desc: "Filter inks by brand name (partial match supported)",
        required: false
  returns code: 200, desc: "A list of matching inks" do
    property :data, array_of: Hash do
      property :id, String, desc: "ID of the ink (macro cluster)"
      property :type, ["macro_cluster"]
      property :attributes, Hash, desc: "Attributes of the ink" do
        property :ink_name, String, desc: "Name of the ink"
      end
    end
  end
  def index
    render json: serializer.serializable_hash.to_json
  end

  api :GET, "/api/v1/inks/:id", "Retrieve details of a specific ink cluster"
  param :id, :number, desc: "ID of the ink cluster (macro cluster)", required: true
  returns code: 200, desc: "Details of the ink cluster" do
    property :data, Hash do
      property :id, String, desc: "ID of the ink (macro cluster)"
      property :type, ["macro_cluster"]
      property :attributes, Hash, desc: "Attributes of the ink" do
        property :brand_name, String, desc: "Brand name of the ink"
        property :ink_name, String, desc: "Name of the ink"
        property :line_name, String, desc: "Line name of the ink"
        property :color, String, desc: "Average color hex code of the ink"
        property :description, String, desc: "Detailed description of the ink (formatted markdown)"
        property :public_collected_inks_count,
                 Integer,
                 desc: "Number of public collections containing this ink"
        property :colors, array_of: String, desc: "All unique colors reported for this ink"
        property :tags, array_of: String, desc: "Tags associated with this ink cluster"
        property :all_names, array_of: Hash, desc: "Alternative names this ink is known by" do
          property :brand_name, String, desc: "Brand name variant"
          property :line_name, String, desc: "Line name variant"
          property :ink_name, String, desc: "Ink name variant"
          property :collected_inks_count,
                   Integer,
                   desc: "Number of collections with this exact name"
        end
      end
      property :relationships, Hash, desc: "Relationships of the ink" do
        property :reviews, Hash, desc: "Approved reviews for this ink", required: false do
          property :data, array_of: Hash do
            property :id, String, desc: "ID of the review"
            property :type, ["ink_review"]
          end
        end
      end
    end
  end
  returns code: 404, desc: "Ink cluster not found"
  def show
    ink = MacroCluster.find(params[:id])
    render json:
             InkDetailSerializer
               .new(ink, include: [:approved_ink_reviews])
               .serializable_hash
               .to_json
  end

  private

  def clusters
    MacroCluster.autocomplete_ink_search(params[:term], params[:brand_name])
  end

  def serializer
    MacroClusterSerializer.new(clusters, fields: { macro_cluster: [:ink_name] })
  end
end
