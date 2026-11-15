class Admins::Descriptions::BrandsController < Admins::BaseController
  helper_method :calculate_diff

  def index
    @versions =
      PaperTrail::Version
        .where(item_type: "BrandCluster")
        .where("object_changes like ?", "%description%")
        .order("id desc")
        .page(params[:page])
        .per(100)
  end

  private

  def calculate_diff(version)
    return "" unless version.changeset.key?("description")

    old_description, new_description = version.changeset["description"]
    WordDiff.new(new_description, old_description).html
  end
end
