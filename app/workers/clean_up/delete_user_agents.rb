class CleanUp::DeleteUserAgents
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  def perform(user_ids)
    UserAgent.where(id: user_ids).delete_all
  end
end
