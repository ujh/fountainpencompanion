class Admins::InkBrandsController < Admins::BaseController

  def index
    @ink_brands = InkBrand.public.order("ink_brands.popular_name ASC")
      .where("new_ink_names_count > 0")
      .includes(:collected_inks)
      .page(params[:page])
  end

  def show
    @ink_brand = InkBrand.find(params[:id])
    @new_ink_names = NewInkName.where(ink_brand_id: params[:id])
      .order("new_ink_names.popular_line_name, new_ink_names.popular_name ASC")
      .includes(:collected_inks)
  end
end
