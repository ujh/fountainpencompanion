module ListState
  extend ActiveSupport::Concern

  included { helper_method :list_state }

  private

  def list_state
    sort = params[:sort]
    sort = sort.is_a?(String) ? sort.first(SearchQuery::MAX_LENGTH) : ""
    { q: search_query, sort: sort }.compact_blank
  end
end
