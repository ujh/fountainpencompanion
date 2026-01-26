class Api::V1::CollectedPensController < Api::V1::BaseController
  resource_description do
    short "Collected Pens. A user's collection of pens"
    formats ["json"]
    description "Endpoints for managing user's collected pens."
  end

  api :GET, "/api/v1/collected_pens", "Retrieve a list of the user's collected pens"
  param :page, Hash, desc: "Pagination parameters" do
    param :number, :number, desc: "Page number"
    param :size, :number, desc: "Number of items per page"
  end
  param :filter, Hash, desc: "Filtering parameters" do
    param :archived, %w[true false], desc: "Filter by archived status"
  end
  param :fields, Hash, desc: "Sparse fieldsets" do
    param :collected_pen,
          String,
          desc: "Comma-separated list of collected pen fields to include in the response"
  end
  returns code: 200, desc: "A list of collected pens" do
    property :data, array_of: Hash do
      property :id, String, desc: "ID of the collected pen"
      property :type, ["collected_pen"]
      property :attributes, Hash, desc: "Attributes of the pen" do
        property :brand, String, desc: "Brand of the pen"
        property :model, String, desc: "Model of the pen"
        property :nib, String, desc: "Nib type of the pen"
        property :color, String, desc: "Color of the pen"
        property :material, String, desc: "Material of the pen"
        property :price, String, desc: "Price of the pen"
        property :trim_color, String, desc: "Trim color of the pen"
        property :filling_system, String, desc: "Filling system of the pen"
        property :comment, String, desc: "User comment about the pen"
        property :archived, [true, false], desc: "Whether the pen is archived"
        property :usage, Integer, desc: "Total usage count of the pen"
        property :daily_usage, Integer, desc: "Daily usage count of the pen"
        property :last_inked, String, desc: "Last inked date of the pen"
        property :last_cleaned, String, desc: "Last cleaned date of the pen"
        property :last_used_on, String, desc: "Last used date of the pen"
        property :inked, [true, false], desc: "Whether the pen is currently inked"
        property :created_at, String, desc: "Creation timestamp of the pen record"
        property :model_variant_id, String, show: false
      end
      property :relationships, Hash, desc: "Relationships of the pen" do
        property :pens_micro_cluster,
                 Hash,
                 desc: "Pens micro cluster relationship",
                 required: false do
          property :data, Hash do
            property :id, String, desc: "ID of the pens micro cluster"
            property :type, ["pens_micro_cluster"]
          end
        end
        property :currently_inkeds, Hash, desc: "Currently inked relationship", required: false do
          property :data, array_of: Hash do
            property :id, String, desc: "ID of the currently inked record"
            property :type, ["currently_inked"]
          end
        end
      end
    end
    property :meta, Hash do
      property :pagination, Hash, desc: "Pagination details" do
        property :total_pages, Integer, desc: "Total number of pages"
        property :current_page, Integer, desc: "Current page number"
        property :next_page, Integer, desc: "Next page number"
        property :prev_page, Integer, desc: "Previous page number"
      end
    end
  end

  def index
    render json: serializer.serializable_hash.to_json
  end

  private

  def serializer
    CollectedPenSerializer.new(collected_pens, options)
  end

  def collected_pens
    @collected_pens ||=
      begin
        relation =
          current_user
            .collected_pens
            .includes(
              :currently_inkeds,
              :usage_records,
              newest_currently_inked: :last_usage,
              pens_micro_cluster: {
                model_variant: :model_micro_cluster
              }
            )
            .order("brand, model, nib, color, comment")
        relation = filter(relation)
        relation.page(params.dig(:page, :number)).per(params.dig(:page, :size))
      end
  end

  def filter(rel)
    relation = rel
    if archived = params.dig(:filter, :archived)
      relation = relation.archived if archived == "true"
      relation = relation.active if archived == "false"
    end
    relation
  end

  def options
    { fields: { collected_pen: collected_pen_fields }, meta: { pagination: pagination } }
  end

  def pagination
    {
      total_pages: collected_pens.total_pages,
      current_page: collected_pens.current_page,
      next_page: collected_pens.next_page,
      prev_page: collected_pens.prev_page
    }
  end

  def collected_pen_fields
    if params.dig(:fields, :collected_pen).present?
      params[:fields][:collected_pen].split(",").map(&:strip)
    else
      CollectedPenSerializer.attributes_to_serialize.keys
    end
  end
end
