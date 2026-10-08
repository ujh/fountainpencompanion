class CspReportsController < ActionController::API
  MAX_BODY_SIZE = 16.kilobytes

  def create
    body = request.body.read(MAX_BODY_SIZE + 1).to_s
    return head(:content_too_large) if body.bytesize > MAX_BODY_SIZE

    payload = JSON.parse(body)
    report = payload["csp-report"] if payload.is_a?(Hash)
    CspReport.record(report, user_agent: request.user_agent) if report.is_a?(Hash)
    head :no_content
  rescue JSON::ParserError
    head :bad_request
  end
end
