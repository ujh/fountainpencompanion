class CheckInkClustering::Human < CheckInkClustering::Base
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
    if micro_cluster.collected_inks.present?
      chat_completion(loop: true, openai: "gpt-4.1", available_tools: [:send_email])
    else
      agent_log.update(
        extra_data: {
          "action" => "reject",
          "explanation_of_decision" =>
            "The micro cluster has no inks in it. It is not possible to cluster an empty micro cluster."
        }
      )
    end
    agent_log.waiting_for_approval!
    micro_cluster_agent_log.approve!
  end

  function :send_email,
           "Send email to human reviewer",
           subject: {
             type: "string",
             description: "Subject of the email"
           },
           body: {
             type: "string",
             description: "Body of the email"
           } do |arguments|
    AdminMailer.agent_mail(arguments[:subject], arguments[:body]).deliver_later
    stop_looping!
  end
end
