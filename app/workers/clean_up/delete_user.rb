class CleanUp::DeleteUser
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  def perform(user_id)
    user = User.find_by(id: user_id)
    user.destroy if user
  end
end
