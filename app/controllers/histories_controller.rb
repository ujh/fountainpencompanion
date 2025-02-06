class HistoriesController < ApplicationController
  helper_method :calculate_diff

  def show
    set_breadcrumbs!
    @versions = object.description_versions.page(params[:page]).per(1)
  end

  private

  def set_breadcrumbs!
    case object
    when MacroCluster
      add_breadcrumb "Inks", "/brands"
      add_breadcrumb "#{object.brand_cluster.name}", brand_path(object.brand_cluster)
      add_breadcrumb "#{object.name}", brand_ink_path(object.brand_cluster, object)
      add_breadcrumb "History", ink_history_path(object)
    when BrandCluster
      add_breadcrumb "#{object.name}", brand_path(object)
      add_breadcrumb "History", brand_history_path(object)
    end
  end

  def calculate_diff(version)
    changes = version.changeset["description"].reverse.map(&:to_s)
    Differ.diff_by_word(*changes).format_as(:html).html_safe
  end

  def object
    @object ||=
      (MacroCluster.find_by(id: params[:ink_id]) || BrandCluster.find_by(id: params[:brand_id]))
  end
end
