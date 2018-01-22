json.collected_inks @collected_inks do |ci|
  json.(ci, :id, :brand_name, :line_name, :ink_name, :kind, :comment, :private)
end
