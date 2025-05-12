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
  end
end
