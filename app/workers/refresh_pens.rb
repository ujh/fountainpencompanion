class RefreshPens
  include Sidekiq::Worker

  def perform(ids = [])
    if ids.empty?
      CollectedPen.in_batches(of: 100) do |batch|
        RefreshPens.perform_async(batch.pluck(:id))
      end
    else
      CollectedPen
        .where(id: ids)
        .find_each { |pen| SaveCollectedPen.new(pen, {}).perform }
    end
  end
end
