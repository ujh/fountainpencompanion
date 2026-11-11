class UnflagSameIpSignUpsBehindFly < ActiveRecord::Migration[8.1]
  def up
    safety_assured { execute <<~SQL }
        UPDATE users
        SET bot = false, bot_reason = NULL
        WHERE bot_reason = 'sign_up_ip_24h_timeframe'
          AND created_at >= '2026-10-14'
      SQL
  end

  def down
  end
end
