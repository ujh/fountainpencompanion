FactoryBot.define do
  factory(:collected_pen) do
    user
    brand { "Wing Sung" }
    model { "618" }
    nib { "M" }
    color { "black" }
  end
end
