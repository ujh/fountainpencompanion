class ScheduleCollectedInkColorCleanup < ActiveRecord::Migration[8.1]
  def up
    NormalizeCollectedInkColors.perform_async
  end

  def down
  end
end
