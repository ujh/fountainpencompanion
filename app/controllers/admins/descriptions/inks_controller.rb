class Admins::Descriptions::InksController < Admins::BaseController
  helper_method :calculate_diffs

  def index
    @versions =
      PaperTrail::Version
        .where(item_type: "MacroCluster")
        .where(
          "object_changes LIKE ? OR object_changes LIKE ? OR object_changes LIKE ? OR object_changes LIKE ?",
          "%description%",
          "%manual_brand_name%",
          "%manual_line_name%",
          "%manual_ink_name%"
        )
        .order("id desc")
        .page(params[:page])
        .per(100)
  end

  private

  TRACKED_FIELDS = {
    "description" => "Description",
    "manual_brand_name" => "Brand Name",
    "manual_line_name" => "Line Name",
    "manual_ink_name" => "Ink Name"
  }.freeze

  def calculate_diffs(version)
    TRACKED_FIELDS.filter_map do |field, label|
      next unless version.changeset.key?(field)

      changes = version.changeset[field].reverse.map(&:to_s)
      diff = Differ.diff_by_word(*changes).format_as(:html).html_safe

      { label: label, diff: diff }
    end
  end
end
