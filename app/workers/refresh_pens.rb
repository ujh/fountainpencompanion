class RefreshPens
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker

  sidekiq_throttle concurrency: { limit: 1 }

  def perform(ids = [])
    if ids.empty?
      CollectedPen.in_batches(of: 100) { |batch| RefreshPens.perform_async(batch.pluck(:id)) }
    else
      CollectedPen.where(id: ids).find_each { |pen| SaveCollectedPen.new(pen, {}).perform }
    end
  end
end
