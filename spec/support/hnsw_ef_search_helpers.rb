module HnswEfSearchHelpers
  def hnsw_ef_search
    ActiveRecord::Base.connection.select_value("SELECT current_setting('hnsw.ef_search', true)")
  end

  def hnsw_ef_search_during_nearest_neighbor_queries
    values = []
    callback = lambda { |*, payload| values << hnsw_ef_search if payload[:sql].include?("<=>") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    values
  end
end
