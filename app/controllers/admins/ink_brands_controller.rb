class Admins::InkBrandsController < Admins::BaseController

  def index
    @ink_brands = InkBrand.public.order("ink_brands.popular_name ASC").includes(:collected_inks, :new_ink_names)
  end
end
