class CheckInkClustering::Human < CheckInkClustering::Base
  class SendEmail < RubyLLM::Tool
    description "Send email to human reviewer"

    param :subject, desc: "Subject of the email"
    param :body, desc: "Body of the email"

    def execute(subject:, body:)
      AdminMailer.agent_mail(subject, body).deliver_later
      halt "email sent"
    end
  end

  class PreviousAgentLogs < RubyLLM::Tool
    description "All logs of interactions with respect to clustering of this ink"

    attr_accessor :micro_cluster_agent_log, :agent_log

    def initialize(micro_cluster_agent_log, agent_log)
      self.micro_cluster_agent_log = micro_cluster_agent_log
      self.agent_log = agent_log
    end

    def execute
      micro_cluster = micro_cluster_agent_log.owner
      logs = micro_cluster.agent_logs.where.not(id: agent_log.id).order(:created_at)
      logs.map { |l| l.slice(:id, :name, :created_at, :extra_data, :state) }.to_json
    end
  end

  def system_directive
    <<~TEXT
      You are reviewing the result of a clustering algorithm that clusters inks,
      creates new clusters, or ignores them. Here the algorithm suggested that the
      ink should be handed over to a human for review.

      Please summarize the reasoning of the AI for this action and send an email
      to the human reviewer.
    TEXT
  end

  def perform
    return unless micro_cluster_agent_log

    if micro_cluster.collected_inks.present?
      prompt = [clustering_explanation, micro_cluster_data].compact.join("\n\n")
      ask(prompt)
      agent_log.waiting_for_approval!
      micro_cluster_agent_log.approve!
    else
      reject_empty_micro_cluster!
    end
  end

  private

  def tools
    [SendEmail.new, PreviousAgentLogs.new(micro_cluster_agent_log, agent_log)]
  end
end
