class CspReport < ApplicationRecord
  DIRECTIVES = %w[
    base-uri
    child-src
    connect-src
    default-src
    font-src
    form-action
    frame-ancestors
    frame-src
    img-src
    manifest-src
    media-src
    object-src
    script-src
    script-src-attr
    script-src-elem
    style-src
    style-src-attr
    style-src-elem
    worker-src
  ].freeze
  EXTENSION_SCHEMES = %w[
    chrome-extension
    moz-extension
    safari-extension
    safari-web-extension
  ].freeze
  INJECTED_SOURCE_FILES = ["sandbox eval code", "user-script"].freeze
  KEYWORD_SOURCE = /\A[a-z][a-z-]{0,31}\z/
  SAMPLE_LENGTH = 500
  USER_AGENT_LENGTH = 500

  def self.record(report, user_agent: nil)
    directive =
      report["effective-directive"].presence || report["violated-directive"].to_s.split.first
    return unless DIRECTIVES.include?(directive)
    return if extension_uri?(report["blocked-uri"]) || extension_uri?(report["source-file"])
    return if INJECTED_SOURCE_FILES.include?(report["source-file"])

    blocked_uri = blocked_source(report["blocked-uri"].to_s)
    return unless blocked_uri

    now = Time.current
    upsert(
      {
        directive: directive,
        blocked_uri: blocked_uri,
        page: page_for(report["document-uri"]),
        sample: sample_for(report),
        user_agent: user_agent_for(user_agent),
        created_at: now,
        updated_at: now
      },
      unique_by: %i[directive blocked_uri page user_agent],
      on_duplicate:
        Arel.sql(
          "count = csp_reports.count + 1, sample = EXCLUDED.sample, updated_at = EXCLUDED.updated_at"
        )
    )
  end

  def self.extension_uri?(value)
    EXTENSION_SCHEMES.include?(value.to_s.split(":", 2).first)
  end

  def self.blocked_source(value)
    return "(none)" if value.blank?
    return value if value.match?(KEYWORD_SOURCE)

    uri = URI.parse(value)
    case uri.scheme
    when "http", "https", "ws", "wss"
      origin(uri)
    when KEYWORD_SOURCE
      "#{uri.scheme}:"
    end
  rescue URI::InvalidURIError
    nil
  end

  def self.origin(uri)
    return if uri.host.blank?

    port = ":#{uri.port}" unless uri.port == uri.default_port
    "#{uri.scheme}://#{uri.host}#{port}"
  end

  def self.page_for(document_uri)
    route = Rails.application.routes.recognize_path(URI.parse(document_uri.to_s).path.to_s)
    "#{route[:controller]}##{route[:action]}"
  rescue URI::InvalidURIError, ActionController::RoutingError
    "unrecognized"
  end

  def self.sample_for(report)
    source = report["source-file"].to_s.split(/[?#]/, 2).first
    location = [source, report["line-number"]].compact_blank.join(":")
    [location, report["script-sample"]].compact_blank.join(" ").truncate(SAMPLE_LENGTH).presence
  end

  def self.user_agent_for(value)
    value.to_s.dup.force_encoding(Encoding::UTF_8).scrub.truncate(USER_AGENT_LENGTH)
  end

  private_class_method :extension_uri?,
                       :blocked_source,
                       :origin,
                       :page_for,
                       :sample_for,
                       :user_agent_for
end
