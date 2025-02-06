class ImportCollectedPen
  include Sidekiq::Worker

  def perform(user_id, row)
    save_pen(user_id, row)
  end

  def save_pen(user_id, row)
    clean_data!(row)
    pen = collected_pen(user_id, row)
    pen.update!(params(row))
  end

  def collected_pen(user_id, row)
    User
      .find(user_id)
      .collected_pens
      .find_or_initialize_by(
        brand: row["brand"].to_s,
        model: row["model"].to_s,
        nib: row["nib"].to_s,
        color: row["color"].to_s
      )
  end

  def clean_data!(row)
    row.keys.each do |k|
      row[k] = "" if row[k].nil?
      row[k] = row[k].strip
    end
  end

  def params(row)
    row["archived_on"] = row["archived"].present? ? Date.current : nil
    row.slice("material", "trim_color", "filling_system", "price", "comment", "archived_on")
  end
end
