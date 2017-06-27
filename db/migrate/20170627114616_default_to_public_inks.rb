class DefaultToPublicInks < ActiveRecord::Migration[5.1]
  def change
    change_column_default(:collected_inks, :private, from: true, to: false)
  end
end
