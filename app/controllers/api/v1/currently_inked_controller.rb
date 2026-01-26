class Api::V1::CurrentlyInkedController < Api::V1::BaseController
  resource_description do
    short "Currently Inked. A user's currently inked pens and inks"
    formats ["json"]
    description "Endpoints for managing user's currently inked pens and inks."
  end

  api :GET, "/api/v1/currently_inked", "Retrieve a list of the user's currently inked pens and inks"
  param :page, Hash, desc: "Pagination parameters" do
    param :number, :number, desc: "Page number"
    param :size, :number, desc: "Number of items per page"
  end
  param :filter, Hash, desc: "Filtering parameters" do
    param :archived, %w[true false], desc: "Filter by archived status"
  end
  param :fields, Hash, desc: "Sparse fieldsets" do
    param :currently_inked,
          String,
          desc: "Comma-separated list of currently inked fields to include in the response"
    param :collected_ink,
          String,
          desc: "Comma-separated list of collected ink fields to include in the response"
    param :collected_pen,
          String,
          desc: "Comma-separated list of collected pen fields to include in the response"
  end
  returns code: 200, desc: "A list of currently inked pens and inks" do
    property :data, array_of: Hash do
      property :id, String, desc: "ID of the currently inked record"
      property :type, ["currently_inked"]
      property :attributes, Hash, desc: "Attributes of the currently inked record" do
        property :inked_on, String, desc: "Date when the pen was inked"
        property :archived_on, String, desc: "Date when the pen was archived"
        property :comment, String, desc: "User comment about the currently inked pen"
        property :last_used_on, String, desc: "Date when the pen was last used"
        property :pen_name, String, desc: "Name of the pen"
        property :ink_name, String, desc: "Name of the ink"
        property :used_today, [true, false], desc: "Whether the pen was used today"
        property :daily_usage, Integer, desc: "Daily usage count of the currently inked pen"
        property :refillable, [true, false], desc: "Whether you can refill the pen with this ink"
        property :unarchivable,
                 [true, false],
                 desc:
                   "Whether this currently inked record can be unarchived (i.e. pen is not currently in use)"
        property :archived, [true, false], desc: "Whether the currently inked record is archived"
      end
      property :relationships, Hash, desc: "Relationships of the currently inked record" do
        property :collected_pen, Hash, desc: "Collected pen relationship", required: false do
          property :data, Hash do
            property :id, String, desc: "ID of the collected pen"
            property :type, ["collected_pen"]
          end
        end
        property :collected_ink, Hash, desc: "Collected ink relationship", required: false do
          property :data, Hash do
            property :id, String, desc: "ID of the collected ink"
            property :type, ["collected_ink"]
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
    property :included, array_of: Hash, desc: "Included related resources" do
      property :id, String, desc: "ID of the related resource"
      property :type, %w[collected_ink collected_pen], desc: "Type of the related resource"
      property :attributes, Hash, desc: "Attributes of the related resource", required: false
      property :relationships, Hash, desc: "Relationships of the related resource", required: false
    end
  end
  def index
    render json: serializer.serializable_hash.to_json
  end

  private

  def serializer
    CurrentlyInkedSerializer.new(currently_inkeds, options)
  end

  def currently_inkeds
    @currently_inkeds ||=
      begin
        relation =
          current_user.currently_inkeds.includes(
            :usage_records,
            :collected_pen,
            :last_usage,
            collected_ink: :micro_cluster,
            collected_pen: {
              pens_micro_cluster: {
                model_variant: :model_micro_cluster
              }
            }
          )
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
    {
      fields: {
        currently_inked: currently_inked_fields,
        collected_ink: collected_ink_fields,
        collected_pen: collected_pen_fields,
        micro_cluster: micro_cluster_fields
      },
      include: includes,
      meta: {
        pagination: pagination
      }
    }
  end

  def pagination
    {
      total_pages: currently_inkeds.total_pages,
      current_page: currently_inkeds.current_page,
      next_page: currently_inkeds.next_page,
      prev_page: currently_inkeds.prev_page
    }
  end

  def includes
    if params[:include].present?
      params[:include].split(",").map(&:strip)
    else
      %i[collected_ink collected_pen collected_ink.micro_cluster]
    end
  end

  def currently_inked_fields
    if params.dig(:fields, :currently_inked).present?
      params[:fields][:currently_inked].split(",").map(&:strip)
    else
      CurrentlyInkedSerializer.attributes_to_serialize.keys + %i[collected_ink collected_pen]
    end
  end

  def collected_ink_fields
    if params.dig(:fields, :collected_ink).present?
      params[:fields][:collected_ink].split(",").map(&:strip)
    else
      %i[brand_name line_name ink_name color archived micro_cluster]
    end
  end

  def collected_pen_fields
    if params.dig(:fields, :collected_pen).present?
      params[:fields][:collected_pen].split(",").map(&:strip)
    else
      %i[brand model nib color model_variant_id]
    end
  end

  def micro_cluster_fields
    %i[macro_cluster]
  end
end
