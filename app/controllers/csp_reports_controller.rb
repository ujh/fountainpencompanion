class CspReportsController < ActionController::API
  MAX_BODY_SIZE = 16.kilobytes

  def create
    return head(:content_too_large) if request.content_length.to_i > MAX_BODY_SIZE

    payload = JSON.parse(request.raw_post)
    report = payload["csp-report"] if payload.is_a?(Hash)
    CspReport.record(report) if report.is_a?(Hash)
    head :no_content
  rescue JSON::ParserError
    head :bad_request
  end
end
