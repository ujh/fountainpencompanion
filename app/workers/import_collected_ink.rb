class ImportCollectedInk
  include Sidekiq::Worker

  def perform(user_id, row)
    SaveCollectedInk.new(
      collected_ink(user_id),
      params(row)
    ).perform
  end

  def collected_ink(user_id)
    User.find(user_id).collected_inks.build
  end

  def params(row)
    row.keys.each {|k|
      row[k] = '' if row[k].nil?
      row[k] = row[k].strip
    }
    row["private"] = !row["private"].blank?
    row["used"] = row["used"].present? ? (["true", "1"].include?(row["used"].downcase)) : false
    row["archived_on"] = row["archived"].present? ? Date.today : nil
    row["kind"] = "bottle" unless row["kind"].present?
    row.slice(
      "brand_name", "line_name", "ink_name", "maker", "kind", "private", "comment", "used", "archived_on"
    )
  end
end
