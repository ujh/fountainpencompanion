class CollectedInks::AddController < ApplicationController
  before_action :authenticate_user!

  def create
    ink = current_user.collected_inks.build
    ink_params = macro_cluster.slice(:brand_name, :line_name, :ink_name)
    ink_params[:kind] = params[:kind]
    SaveCollectedInk.new(ink, ink_params).perform
    head :created
  end

  private

  def macro_cluster
    MacroCluster.find(params[:macro_cluster_id])
  end
end
