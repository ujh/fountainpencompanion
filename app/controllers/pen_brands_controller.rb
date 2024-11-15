class PenBrandsController < ApplicationController
  add_breadcrumb "Pens", "/pen_brands"

  def index
    @brands = Pens::Brand.public.order(:name)
  end

  def show
    @brand = Pens::Brand.public.find(params[:id])
    @models = @brand.public_models.includes(:collected_pens).order(:model)
    add_breadcrumb @brand.name, pen_brand_path(@brand)
  end
end
