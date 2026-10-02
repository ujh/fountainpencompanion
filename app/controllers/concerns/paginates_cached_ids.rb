module PaginatesCachedIds
  extend ActiveSupport::Concern

  private

  # Paginates the sorted ids and only loads the records of the current page.
  # This avoids sending the whole list of ids to the database on every request.
  def paginate_ids(ids, scope, page_param, per_page:)
    page_ids = Kaminari.paginate_array(ids).page(params[page_param]).per(per_page).to_a
    records = scope.where(id: page_ids).index_by(&:id)
    Kaminari
      .paginate_array(records.values_at(*page_ids).compact, total_count: ids.size)
      .page(params[page_param])
      .per(per_page)
  end
end
