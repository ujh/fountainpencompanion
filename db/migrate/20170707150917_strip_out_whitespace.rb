class StripOutWhitespace < ActiveRecord::Migration[5.1]
  def up
    CollectedInk.find_each do |ci|
      print "."
      ci.brand_name.strip!
      ci.line_name.strip!
      ci.ink_name.strip!
      ci.save
    end
  end
end
