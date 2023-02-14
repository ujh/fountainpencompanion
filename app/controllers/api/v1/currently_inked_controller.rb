class Api::V1::CurrentlyInkedController < Api::V1::BaseController
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
            collected_ink: :micro_cluster
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
      CurrentlyInkedSerializer.attributes_to_serialize.keys +
        %i[collected_ink collected_pen]
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
      %i[brand model nib color]
    end
  end

  def micro_cluster_fields
    %i[macro_cluster]
  end
end
