class Api::V1::CollectedInksController < Api::V1::BaseController
  resource_description do
    short "Collected Inks. A user's collection of inks"
    formats ["json"]
    description "Endpoints for managing user's collected inks."
  end

  before_action :set_collected_ink, only: %i[show update destroy]

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
    param :macro_cluster_id, :number, desc: "Filter by macro cluster ID (ink_id)"
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
        property :cluster_tags, array_of: String, desc: "Tags from the ink cluster"
        property :kind, String, desc: "Type of ink (bottle, sample, cartridge, swab)"
        property :swabbed, [true, false], desc: "Whether the ink has been swabbed"
        property :used, [true, false], desc: "Whether the ink has been used"
        property :comment, String, desc: "User comment about the ink"
        property :private_comment, String, desc: "Private comment about the ink"
        property :simplified_brand_name, String, desc: "Simplified brand name for matching"
        property :simplified_ink_name, String, desc: "Simplified ink name for matching"
        property :simplified_line_name, String, desc: "Simplified line name for matching"
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

  api :GET, "/api/v1/collected_inks/:id", "Retrieve a single collected ink"
  param :id, :number, required: true, desc: "ID of the collected ink"
  returns code: 200, desc: "A single collected ink" do
    property :data, Hash do
      property :id, String, desc: "ID of the collected ink"
      property :type, ["collected_ink"]
      property :attributes, Hash, desc: "Attributes of the ink"
    end
  end
  returns code: 404, desc: "Collected ink not found"

  def show
    render json: single_serializer.serializable_hash.to_json
  end

  api :POST, "/api/v1/collected_inks", "Create a new collected ink"
  param :data, Hash, required: true, desc: "Collected ink data" do
    param :type, ["collected_ink"], required: true, desc: "Resource type"
    param :attributes, Hash, required: true, desc: "Attributes of the ink" do
      param :brand_name, String, required: true, desc: "Brand name of the ink (1-100 characters)"
      param :ink_name, String, required: true, desc: "Name of the ink (1-100 characters)"
      param :line_name, String, desc: "Line name of the ink (1-100 characters)"
      param :maker, String, desc: "Maker of the ink"
      param :kind, %w[bottle sample cartridge swab], desc: "Type of ink"
      param :color, String, desc: "Color hex code of the ink (e.g., '#FF0000')"
      param :swabbed, [true, false], desc: "Whether the ink has been swabbed"
      param :used, [true, false], desc: "Whether the ink has been used"
      param :comment, String, desc: "User comment about the ink"
      param :private_comment, String, desc: "Private comment about the ink"
      param :private, [true, false], desc: "Whether the ink is private"
      param :archived, [true, false], desc: "Whether the ink is archived"
      param :tags_as_string, String, desc: "Comma-separated list of tags"
    end
  end
  returns code: 201, desc: "Collected ink created successfully"
  returns code: 422, desc: "Validation errors"

  def create
    ink = current_user.collected_inks.build
    if SaveCollectedInk.new(ink, collected_ink_params).perform
      render json: CollectedInkSerializer.new(ink).serializable_hash.to_json, status: :created
    else
      render json: { errors: format_errors(ink) }, status: :unprocessable_entity
    end
  end

  api :PATCH, "/api/v1/collected_inks/:id", "Update a collected ink"
  param :id, :number, required: true, desc: "ID of the collected ink"
  param :data, Hash, required: true, desc: "Collected ink data" do
    param :type, ["collected_ink"], required: true, desc: "Resource type"
    param :attributes, Hash, required: true, desc: "Attributes of the ink" do
      param :brand_name, String, desc: "Brand name of the ink (1-100 characters)"
      param :ink_name, String, desc: "Name of the ink (1-100 characters)"
      param :line_name, String, desc: "Line name of the ink (1-100 characters)"
      param :maker, String, desc: "Maker of the ink"
      param :kind, %w[bottle sample cartridge swab], desc: "Type of ink"
      param :color, String, desc: "Color hex code of the ink (e.g., '#FF0000')"
      param :swabbed, [true, false], desc: "Whether the ink has been swabbed"
      param :used, [true, false], desc: "Whether the ink has been used"
      param :comment, String, desc: "User comment about the ink"
      param :private_comment, String, desc: "Private comment about the ink"
      param :private, [true, false], desc: "Whether the ink is private"
      param :archived, [true, false], desc: "Whether the ink is archived"
      param :tags_as_string, String, desc: "Comma-separated list of tags"
    end
  end
  returns code: 200, desc: "Collected ink updated successfully"
  returns code: 404, desc: "Collected ink not found"
  returns code: 422, desc: "Validation errors"

  def update
    if SaveCollectedInk.new(@collected_ink, collected_ink_params).perform
      render json: single_serializer.serializable_hash.to_json
    else
      render json: { errors: format_errors(@collected_ink) }, status: :unprocessable_entity
    end
  end

  api :DELETE, "/api/v1/collected_inks/:id", "Delete a collected ink"
  param :id, :number, required: true, desc: "ID of the collected ink"
  returns code: 204, desc: "Collected ink deleted successfully"
  returns code: 404, desc: "Collected ink not found"

  def destroy
    @collected_ink.destroy
    head :no_content
  end

  private

  def set_collected_ink
    @collected_ink = current_user.collected_inks.find(params[:id])
  end

  def single_serializer
    CollectedInkSerializer.new(@collected_ink, single_options)
  end

  def collected_ink_params
    params
      .require(:data)
      .require(:attributes)
      .permit(
        :brand_name,
        :line_name,
        :ink_name,
        :maker,
        :kind,
        :swabbed,
        :used,
        :comment,
        :private_comment,
        :color,
        :private,
        :tags_as_string
      )
  end

  def format_errors(ink)
    ink.errors.map do |error|
      { source: { pointer: "/data/attributes/#{error.attribute}" }, detail: error.full_message }
    end
  end

  def single_options
    { fields: { collected_ink: collected_ink_fields } }
  end

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
    if macro_cluster_id = params.dig(:filter, :macro_cluster_id)
      relation =
        relation.joins(:micro_cluster).where(micro_clusters: { macro_cluster_id: macro_cluster_id })
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
