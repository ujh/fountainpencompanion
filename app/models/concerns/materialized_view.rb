# Read-only model backed by a materialized Scenic view
module MaterializedView
  extend ActiveSupport::Concern

  class_methods do
    # Refreshes concurrently (without blocking reads) when possible. That
    # requires the view to have been populated before, which isn't the case
    # when the database was set up from structure.sql.
    def refresh
      Scenic.database.refresh_materialized_view(
        table_name,
        concurrently: Scenic.database.populated?(table_name),
        cascade: false
      )
    end
  end

  def readonly?
    true
  end
end
