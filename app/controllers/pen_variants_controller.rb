class PenVariantsController < ApplicationController
  add_breadcrumb "Pens", "/pen_brands"

  def show
    @variant = Pens::ModelVariant.find(params[:id])
    @model = @variant.pen_model
    @brand = @model.pen_brand
    add_breadcrumb @brand.name, pen_brand_path(@brand)
    add_breadcrumb @model.model, pen_brand_pen_model_path(@brand, @model)
    add_breadcrumb @variant.name, pen_brand_pen_model_pen_variant_path(@brand, @model, @variant)

    unless params[:pen_brand_id]
      redirect_to pen_brand_pen_model_pen_variant_path(@brand, @model, @variant)
    end
  end
end
