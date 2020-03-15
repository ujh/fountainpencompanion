class Admins::MacroClustersController < Admins::BaseController

  def destroy
    cluster = MacroCluster.find(params[:id])
    cluster.destroy!
    head :ok
  end
end
