class HistoriesController < ApplicationController
  helper_method :history_path

  def show
    set_breadcrumbs!
    @version =
      (
        if params[:v]
          (object.versions[params[:v].to_i] || object.versions.last)
        else
          object.versions.last
        end
      )
    @previous_index = @version.previous&.index
    @next_index = @version.next&.index
    @diff =
      Differ.diff_by_word(
        *@version.changeset["description"].reverse.map(&:to_s)
      ).format_as(:html)
  end

  private

  def set_breadcrumbs!
    case object
    when MacroCluster
      add_breadcrumb "Inks", "/brands"
      add_breadcrumb "#{object.brand_cluster.name}",
                     brand_path(object.brand_cluster)
      add_breadcrumb "#{object.name}",
                     brand_ink_path(object.brand_cluster, object)
      add_breadcrumb "History", ink_history_path(object)
    when BrandCluster
      add_breadcrumb "#{object.name}", brand_path(object)
      add_breadcrumb "History", brand_history_path(object)
    end
  end

  def history_path(obj, **kwargs)
    case obj
    when MacroCluster
      ink_history_path(obj, **kwargs)
    when BrandCluster
      brand_history_path(obj, **kwargs)
    end
  end

  def object
    @object ||=
      (
        MacroCluster.find_by(id: params[:ink_id]) ||
          BrandCluster.find_by(id: params[:brand_id])
      )
  end
end
