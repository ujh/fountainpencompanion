class ImportCollectedInk
  include Sidekiq::Worker
  include ImportDateParser

  NAME_FIELDS = %w[brand_name line_name ink_name].freeze

  # Rows describing the same ink (and kind) more than once are imported as
  # separate inks. They need to be passed to the same job, so that they are
  # processed in order and re-importing a file updates the same records.
  def self.duplicate_key(row)
    NAME_FIELDS.map { |field| row[field].to_s.strip } + [row["kind"].to_s.strip.downcase]
  end

  attr_accessor :user

  def perform(user_id, rows)
    self.user = User.find(user_id)
    rows.each_with_index do |row, occurrence|
      SaveCollectedInk.new(collected_ink(row, occurrence), params(row)).perform
    end
  end

  def collected_ink(row, occurrence)
    *names, kind = self.class.duplicate_key(row)
    name_attributes = NAME_FIELDS.zip(names).to_h
    existing = user.collected_inks.where(name_attributes)
    existing = existing.where(kind: kind) if kind.present?
    existing.order(:id).offset(occurrence).first || user.collected_inks.build(name_attributes)
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
    row["kind"] = row["kind"].strip.downcase
    row["tags_as_string"] = row["tags"] || ""
    sliced =
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
    created_at = parse_date(row["date_added"])
    sliced["created_at"] = created_at if created_at
    sliced
  end

  def to_b(str)
    str.present? && !%w[false f 0].include?(str.downcase)
  end
end
