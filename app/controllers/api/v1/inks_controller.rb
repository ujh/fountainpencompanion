class Api::V1::InksController < Api::V1::BaseController
  api :GET, "/api/v1/inks", "Returns a list of ink clusters"
  param :filter, Hash, desc: "Filtering options" do
    param :ink_name, String, desc: "Filter by ink name"
    param :line_name, String, desc: "Filter by line name"
    param :brand_name, String, desc: "Filter by brand name"
  end
  param :fields, Hash, desc: "Fields to include in the response" do
    param :macro_cluster, String, desc: "Comma-separated list of macro cluster fields to include"
  end
  param :page, Hash, desc: "Pagination options" do
    param :number, :number, desc: "Page number"
    param :size, :number, desc: "Number of items per page"
  end
  returns code: 200, desc: "List of ink clusters" do
    property :data, array_of: Hash, desc: "Array of macro cluster objects" do
      property :id, String, desc: "Macro cluster ID"
      property :type, String, desc: "Resource type (macro_cluster)"
      property :attributes, Hash, desc: "Macro cluster attributes" do
        property :brand_name, String, desc: "Brand name"
        property :line_name, String, desc: "Line name"
        property :ink_name, String, desc: "Ink name"
        property :color, String, desc: "Hex color code"
        property :description, String, desc: "Ink description"
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
               desc: "Related resources",
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
    property :meta, Hash, desc: "Metadata" do
      property :pagination, Hash, desc: "Pagination info" do
        property :current_page, Integer, desc: "Current page number"
        property :next_page, Integer, desc: "Next page number", required: false, default_value: nil
        property :prev_page,
                 Integer,
                 desc: "Previous page number",
                 required: false,
                 default_value: nil
        property :total_pages, Integer, desc: "Total number of pages"
        property :total_count, Integer, desc: "Total number of items"
      end
    end
  end
  def index
    render json: serializer.serializable_hash.to_json
  end

  private

  def clusters
    @clusters ||=
      begin
        relation = MacroCluster.includes(:collected_inks)
        if params.dig(:filter, :ink_name).present?
          relation =
            relation.autocomplete_ink_search(
              params[:filter][:ink_name],
              params[:filter][:brand_name]
            )
        end
        if params.dig(:filter, :line_name).present?
          relation =
            relation.autocomplete_line_search(
              params[:filter][:line_name],
              params[:filter][:brand_name]
            )
        end
        relation.page(params.dig(:page, :number)).per(params.dig(:page, :size))
      end
  end

  def serializer
    MacroClusterSerializer.new(clusters, options)
  end

  def options
    { fields: { macro_cluster: macro_cluster_fields }, meta: { pagination: pagination } }
  end

  def macro_cluster_fields
    params.dig(:fields, :macro_cluster)&.split(",")&.map(&:strip) ||
      MacroClusterSerializer.attributes_to_serialize.keys
  end

  def pagination
    {
      current_page: clusters.current_page,
      next_page: clusters.next_page,
      prev_page: clusters.prev_page,
      total_pages: clusters.total_pages,
      total_count: clusters.total_count
    }
  end
end
