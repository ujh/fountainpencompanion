class ImportCollectedPen
  include Sidekiq::Worker

  def perform(user_id, row)
    User.find(user_id).collected_pens.create!(params(row))
  end


  def params(row)
    row.keys.each {|k|
      row[k] = '' if row[k].nil?
      row[k] = row[k].strip
    }
    row["archived_on"] = row["archived"].present? ? Date.current : nil
    row.slice('brand', 'model', 'comment', 'nib', 'color', 'archived_on')
  end
end
