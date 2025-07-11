class Admins::Descriptions::InksController < Admins::BaseController
  helper_method :calculate_diff

  def index
    @versions =
      PaperTrail::Version
        .where(item_type: "MacroCluster")
        .where("object_changes like ?", "%description%")
        .order("id desc")
        .page(params[:page])
        .per(100)
  end

  private

  def calculate_diff(version)
    return "" unless version.changeset.key?("description")

    changes = version.changeset["description"].reverse.map(&:to_s)
    Differ.diff_by_word(*changes).format_as(:html).html_safe
  end
end
