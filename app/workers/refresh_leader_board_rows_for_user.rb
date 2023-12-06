class RefreshLeaderBoardRowsForUser
  include Sidekiq::Worker

  sidekiq_options queue: "leaderboards"

  def perform(user_id)
    self.user = User.find_by(id: user_id)
    return unless user

    update_brands_row
  end

  private

  attr_accessor :user

  def update_brands_row
    row = LeaderBoardRow::Brands.find_or_initialize_by(user: user)
    row.value =
      user
        .collected_inks
        .where(archived_on: nil, private: false)
        .pluck(
          :brand_name
        )# Intentionally done in Ruby instead of using DISTINCT to put less load on the database
        .
        uniq
        .length
    row.save!
  end
end
