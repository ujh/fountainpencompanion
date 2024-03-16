FactoryBot.define do
  factory(:collected_pen) do
    user
    brand { "Wing Sung" }
    model { "618" }
    nib { "M" }
    color { "black" }
    material { "plastic" }
    trim_color { "gold" }
    filling_system { "piston filler" }
    price { "$10" }
  end
end
