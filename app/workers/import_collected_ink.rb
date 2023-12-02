class ImportCollectedInk
  include Sidekiq::Worker

  def perform(user_id, row)
    SaveCollectedInk.new(collected_ink(user_id, row), params(row)).perform
  end

  def collected_ink(user_id, row)
    User
      .find(user_id)
      .collected_inks
      .find_or_initialize_by(
        brand_name: row["brand_name"].to_s,
        line_name: row["line_name"].to_s,
        ink_name: row["ink_name"].to_s
      )
  end

  def params(row)
    row.keys.each do |k|
      row[k] = "" if row[k].nil?
      row[k] = row[k].strip
    end
    row["private"] = !row["private"].blank?
    row["used"] = to_b(row["used"])
    row["swabbed"] = to_b(row["swabbed"])
    row["archived_on"] = to_b(row["archived"]) ? Date.current : nil
    row["kind"] = "bottle" unless row["kind"].present?
    row["tags_as_string"] = row["tags"]
    row.slice(
      "brand_name",
      "line_name",
      "ink_name",
      "maker",
      "kind",
      "private",
      "comment",
      "used",
      "archived_on",
      "private_comment",
      "swabbed",
      "tags_as_string",
      "color"
    )
  end

  def to_b(str)
    str.present? && !%w[false f 0].include?(str.downcase)
  end
end
