class HistoriesController < ApplicationController
  helper_method :calculate_diffs

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

  def calculate_diffs(version)
    MacroCluster::TRACKED_FIELDS.filter_map do |field, label|
      next unless version.changeset.key?(field)

      if field == "ignored_colors" && version.changeset.key?("color")
        old_color, new_color = version.changeset["color"]
        { label: label, type: :color, old_color: old_color, new_color: new_color }
      elsif field == "line_name_is_empty"
        old_value, new_value = version.changeset[field]
        automatic_line_name = object.automatic_line_name.to_s
        old_display = old_value ? "" : automatic_line_name
        new_display = new_value ? "" : automatic_line_name
        diff = Differ.diff_by_word(new_display, old_display).format_as(:html).html_safe
        { label: "Line Name", type: :text, diff: diff }
      else
        changes = version.changeset[field].reverse.map(&:to_s)
        diff = Differ.diff_by_word(*changes).format_as(:html).html_safe
        { label: label, type: :text, diff: diff }
      end
    end
  end

  def object
    @object ||=
      MacroCluster.find_by(id: params[:ink_id]) || BrandCluster.find_by(id: params[:brand_id])
  end
end
