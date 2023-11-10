class RefreshLeaderBoard::Base
  include Sidekiq::Worker

  sidekiq_options queue: "leaderboards"

  def perform
    LeaderBoard.refresh!(type)
  end

  private

  def type
    self.class.name.demodulize.underscore
  end
end
