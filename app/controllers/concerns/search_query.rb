module SearchQuery
  extend ActiveSupport::Concern

  MAX_LENGTH = 200

  included { helper_method :search_query }

  private

  def search_query
    @search_query ||=
      begin
        raw = params[:q]
        raw.is_a?(String) ? raw.strip.first(MAX_LENGTH) : ""
      end
  end
end
