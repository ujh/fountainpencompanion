class Admins::Agents::InkClusterersController < Admins::BaseController
  before_action :set_agent_log
  before_action :set_next_cluster

  def show
    @queue_length = AdminStats.new.micro_clusters_to_assign_count
    @processing = processing?
  end

  def create
    run_agent!
    redirect_to admins_agents_ink_clusterer_path
  end

  def destroy
    InkClusterer.new(@next_cluster.id).reject!
    run_agent!
    redirect_to admins_agents_ink_clusterer_path
  end

  def update
    InkClusterer.new(@next_cluster.id).approve!
    run_agent!
    redirect_to admins_agents_ink_clusterer_path
  end

  private

  def set_agent_log
    @agent_log = AgentLog.ink_clusterer.waiting_for_approval.first
  end

  def set_next_cluster
    @next_cluster = MicroCluster.for_processing.first
  end

  def run_agent!
    set_agent_log
    set_next_cluster

    return if @agent_log.present?
    return unless @next_cluster.present?
    return if processing?

    RunAgent.perform_async("InkClusterer", @next_cluster.id)
  end

  def processing?
    job_queued? || job_running? || job_retrying?
  end

  def job_queued?
    queued = false
    Sidekiq::Queue.all.each do |queue|
      queued ||= queue.any? { |job| job.klass == "RunAgent" && job.args[0] == "InkClusterer" }
    end
    queued
  end

  def job_running?
    worker_set = Sidekiq::WorkSet.new
    worker_set.any? do |_, _, job|
      job.payload["class"] == "RunAgent" && job.payload["args"][0] == "InkClusterer"
    end
  end

  def job_retrying?
    query = Sidekiq::RetrySet.new
    query
      .scan("RunAgent")
      .select { |retri| retri.display_class == "RunAgent" }
      .any? { |j| j.args.first == "InkClusterer" }
  end
end
