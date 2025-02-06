class RefreshInks
  include Sidekiq::Worker

  def perform(ids = [])
    if ids.empty?
      CollectedInk.in_batches(of: 100) { |batch| RefreshInks.perform_async(batch.pluck(:id)) }
    else
      CollectedInk.where(id: ids).map(&:save)
    end
  end
end
