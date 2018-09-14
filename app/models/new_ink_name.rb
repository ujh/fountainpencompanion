class NewInkName < ApplicationRecord

    belongs_to :ink_brand
    has_many :collected_inks
end
