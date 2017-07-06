class Admins::BrandsController < Admins::BaseController

  def index
    @brands = CollectedInk.order(:brand_name).group(:brand_name).pluck(:brand_name)
  end

  def show
    @inks = CollectedInk.unique_for_brand(params[:id])
  end
end
