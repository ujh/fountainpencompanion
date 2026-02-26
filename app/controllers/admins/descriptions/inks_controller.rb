class Admins::Descriptions::InksController < Admins::BaseController
  helper_method :calculate_diffs

  def index
    conditions = MacroCluster::TRACKED_FIELDS.keys.map { "object_changes LIKE ?" }.join(" OR ")
    values = MacroCluster::TRACKED_FIELDS.keys.map { |f| "%#{f}%" }
    @versions =
      PaperTrail::Version
        .where(item_type: "MacroCluster")
        .where(event: "update")
        .where(conditions, *values)
        .order("id desc")
        .page(params[:page])
        .per(100)
  end

  private

  def calculate_diffs(version)
    MacroCluster::TRACKED_FIELDS.filter_map do |field, label|
      next unless version.changeset.key?(field)

      if field == "ignored_colors" && version.changeset.key?("color")
        old_color, new_color = version.changeset["color"]
        { label: label, type: :color, old_color: old_color, new_color: new_color }
      else
        changes = version.changeset[field].reverse.map(&:to_s)
        diff = Differ.diff_by_word(*changes).format_as(:html).html_safe
        { label: label, type: :text, diff: diff }
      end
    end
  end
end
