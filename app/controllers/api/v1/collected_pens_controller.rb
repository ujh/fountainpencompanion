class Api::V1::CollectedPensController < Api::V1::BaseController
  def index
    render json: serializer.serializable_hash.to_json
  end

  private

  def serializer
    CollectedPenSerializer.new(collected_pens, options)
  end

  def collected_pens
    @collected_pens ||=
      current_user
        .collected_pens
        .includes(
          :currently_inkeds,
          :usage_records,
          newest_currently_inked: :last_usage
        )
        .order("brand, model, nib, color, comment")
        .page(params.dig(:page, :number))
        .per(params.dig(:page, :size))
  end

  def options
    {
      fields: {
        collected_pen: collected_pen_fields
      },
      meta: {
        pagination: pagination
      }
    }
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
