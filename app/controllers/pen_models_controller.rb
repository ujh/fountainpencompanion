class PenModelsController < ApplicationController
  add_breadcrumb "Pens", "/pen_brands"

  def show
    @model = Pens::Model.find(params[:id])
    @brand = @model.pen_brand
    @variants = @model.model_variants.includes(:collected_pens).ordered
    add_breadcrumb @brand.name, pen_brand_path(@brand)
    add_breadcrumb @model.model, pen_brand_pen_model_path(@brand, @model)
  end
end
