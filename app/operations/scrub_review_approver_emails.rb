class ScrubReviewApproverEmails
  USER_FIELD_WITH_EMAIL = /\\"user\\":\\"[^\\"]*@[^\\"]*\\"/
  SCRUBBED_USER_FIELD = '\"user\":\"user\"'.freeze

  def perform
    scrubbed = 0
    logs.find_each do |log|
      json = log.transcript.to_json
      next unless json.match?(USER_FIELD_WITH_EMAIL)

      log.update_column(
        :transcript,
        JSON.parse(json.gsub(USER_FIELD_WITH_EMAIL) { SCRUBBED_USER_FIELD })
      )
      scrubbed += 1
    end
    scrubbed
  end

  private

  def logs
    AgentLog.where(name: "ReviewApprover")
  end
end
