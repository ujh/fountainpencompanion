class ImportCurrentlyInked
  include Sidekiq::Worker

  def perform(user_id, row)
    self.user = User.find(user_id)
    user.currently_inkeds.create!(params(row))
  end

  private

  attr_accessor :user

  def params(row)
    row.keys.each do |k|
      row[k] = "" if row[k].nil?
      row[k] = row[k].strip
    end
    row["collected_ink"] = user.collected_inks.find_by(
      brand_name: row["ink_brand"],
      line_name: row["ink_line"],
      ink_name: row["ink_name"]
    )
    row["collected_pen"] = user.collected_pens.find_by(
      brand: row["pen_brand"],
      model: row["pen_model"],
      nib: row["pen_nib"]
    )
    row["archived_on"] = Date.parse(row["archived_on"]) if row[
      "archived_on"
    ].present?
    row["inked_on"] = Date.parse(row["inked_on"]) if row["inked_on"].present?
    row.slice(
      "collected_ink",
      "collected_pen",
      "comment",
      "inked_on",
      "archived_on"
    )
  end
end
