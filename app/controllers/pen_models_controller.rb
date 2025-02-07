class PenModelsController < ApplicationController
  add_breadcrumb "Pens", "/pen_brands"

  def index
    @embeddings = Pens::Model.embedding_search(params[:q])
  end

  def show
    @model = Pens::Model.find(params[:id])
    @brand = @model.pen_brand
    @variants = @model.model_variants.includes(:collected_pens).ordered
    add_breadcrumb @brand.name, pen_brand_path(@brand)
    add_breadcrumb @model.model, pen_brand_pen_model_path(@brand, @model)

    redirect_to pen_brand_pen_model_path(@brand, @model) unless params[:pen_brand_id]
  end
end
