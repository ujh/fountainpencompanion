class RefreshInks
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker

  sidekiq_throttle concurrency: { limit: 1 }

  def perform(ids = [])
    if ids.empty?
      CollectedInk.in_batches(of: 100) { |batch| RefreshInks.perform_async(batch.pluck(:id)) }
    else
      CollectedInk.where(id: ids).map(&:save)
    end
  end
end
