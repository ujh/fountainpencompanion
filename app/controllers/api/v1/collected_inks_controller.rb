class Api::V1::CollectedInksController < Api::V1::BaseController
  resource_description do
    short "Collected Inks. A user's collection of inks"
    formats ["json"]
    description "Endpoints for managing user's collected inks."
  end

  api :GET, "/api/v1/collected_inks", "Retrieve a list of the user's collected inks"
  param :page, Hash, desc: "Pagination parameters" do
    param :number, :number, desc: "Page number"
    param :size, :number, desc: "Number of items per page"
  end
  param :sort,
        %w[name date_added date_added_asc],
        desc:
          "Sort order: 'name' (default) for alphabetical, 'date_added' for creation date (newest first), 'date_added_asc' for creation date (oldest first)"
  param :filter, Hash, desc: "Filtering parameters" do
    param :archived, %w[true false], desc: "Filter by archived status"
    param :swabbed, %w[true false], desc: "Filter by swabbed status"
    param :used, %w[true false], desc: "Filter by used status"
  end
  param :fields, Hash, desc: "Sparse fieldsets" do
    param :collected_ink,
          String,
          desc: "Comma-separated list of collected ink fields to include in the response"
  end
  returns code: 200, desc: "A list of collected inks" do
    property :data, array_of: Hash do
      property :id, String, desc: "ID of the collected ink"
      property :type, ["collected_ink"]
      property :attributes, Hash, desc: "Attributes of the ink" do
        property :brand_name, String, desc: "Brand name of the ink"
        property :line_name, String, desc: "Line name of the ink"
        property :ink_name, String, desc: "Name of the ink"
        property :maker, String, desc: "Maker of the ink"
        property :color, String, desc: "Color hex code of the ink"
        property :kind, String, desc: "Type of ink (bottle, sample, cartridge, swab)"
        property :swabbed, [true, false], desc: "Whether the ink has been swabbed"
        property :used, [true, false], desc: "Whether the ink has been used"
        property :comment, String, desc: "User comment about the ink"
        property :private_comment, String, desc: "Private comment about the ink"
        property :private, [true, false], desc: "Whether the ink is private"
        property :archived, [true, false], desc: "Whether the ink is archived"
        property :archived_on, String, desc: "Date when the ink was archived"
        property :usage, Integer, desc: "Total usage count of the ink"
        property :daily_usage, Integer, desc: "Daily usage count of the ink"
        property :last_used_on, String, desc: "Last used date of the ink"
        property :ink_id, Integer, desc: "ID of the associated macro cluster"
        property :created_at, String, desc: "Creation timestamp of the ink record"
      end
      property :relationships, Hash, desc: "Relationships of the ink" do
        property :micro_cluster, Hash, desc: "Micro cluster relationship", required: false do
          property :data, Hash do
            property :id, String, desc: "ID of the micro cluster"
            property :type, ["micro_cluster"]
          end
        end
        property :tags, Hash, desc: "Tags relationship", required: false do
          property :data, array_of: Hash do
            property :id, String, desc: "ID of the tag"
            property :type, ["tag"]
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
    CollectedInkSerializer.new(collected_inks, options)
  end

  def collected_inks
    @collected_inks ||=
      begin
        relation =
          current_user.collected_inks.includes(
            :currently_inkeds,
            :usage_records,
            :tags,
            micro_cluster: :macro_cluster,
            newest_currently_inked: :last_usage
          )
        relation = sort(relation)
        relation = filter(relation)
        relation.page(params.dig(:page, :number)).per(params.dig(:page, :size))
      end
  end

  def sort(rel)
    case params[:sort]
    when "date_added"
      rel.order(created_at: :desc)
    when "date_added_asc"
      rel.order(created_at: :asc)
    else
      rel.order("brand_name, line_name, ink_name")
    end
  end

  def filter(rel)
    relation = rel
    if archived = params.dig(:filter, :archived)
      relation = relation.archived if archived == "true"
      relation = relation.active if archived == "false"
    end
    if swabbed = params.dig(:filter, :swabbed)
      relation = relation.where(swabbed: swabbed == "true")
    end
    if used = params.dig(:filter, :used)
      relation = relation.where(used: used == "true")
    end
    relation
  end

  def options
    { fields: { collected_ink: collected_ink_fields }, meta: { pagination: pagination } }
  end

  def pagination
    {
      total_pages: collected_inks.total_pages,
      current_page: collected_inks.current_page,
      next_page: collected_inks.next_page,
      prev_page: collected_inks.prev_page
    }
  end

  def collected_ink_fields
    if params.dig(:fields, :collected_ink).present?
      params[:fields][:collected_ink].split(",").map(&:strip)
    else
      CollectedInkSerializer.attributes_to_serialize.keys
    end
  end
end
