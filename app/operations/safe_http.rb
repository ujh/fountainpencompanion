require "ssrf_filter"
require "ipaddr"
require "resolv"

# Thin wrapper around the ssrf_filter gem that provides:
#
# - A small compatibility shim so existing callers can keep using
#   `.status` (Integer), `.headers["content-type"]`, `.body`, and
#   `.env.url.to_s` regardless of the underlying Net::HTTPResponse API.
# - A `.allowed?(url)` URL-only validator used at unfurl time before
#   persisting an attacker-controlled `og:image` URL: we never want to
#   store a URL that points at an internal address even if we don't
#   fetch it ourselves (an admin's browser would later fetch it with
#   their cookies).
# - Status-aware Faraday exceptions for non-2xx responses (mirrors the
#   `:raise_error` middleware Faraday provides), so callers that look
#   for e.g. `Faraday::ForbiddenError` keep working.
# - Wrapping of network-level exceptions (SocketError, Errno::*, SSL,
#   IO, EOF) into `Faraday::ConnectionFailed`, again so callers that
#   already rescue `Faraday::Error` cover the same failure modes they
#   did before.
#
# Note on response-size protection: ssrf_filter calls `Net::HTTP#request`
# without a streaming block, which buffers the response body. The
# post-fetch size check below is a backstop only; the primary defense
# against giant payloads is the read timeout.
class SafeHttp
  MAX_REDIRECTS = 5
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  MAX_BODY_BYTES = 5 * 1024 * 1024

  HTTP_OPTIONS = { open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT }.freeze

  class BlockedError < Faraday::Error
  end

  class ResponseTooLarge < BlockedError
  end

  Response =
    Struct.new(:status, :headers, :body, :final_url) do
      Env = Struct.new(:url)

      # Mimics Faraday::Response#env so callers can read the final URL after
      # redirects: `response.env.url.to_s`.
      def env
        Env.new(URI(final_url))
      end
    end

  def self.get(url, headers: {})
    fetch(:get, url, headers: headers)
  end

  def self.head(url, headers: {})
    fetch(:head, url, headers: headers)
  end

  # URL-only safety check. True when the URL has an http(s) scheme, the
  # host resolves at all, and at least one resolved IP is globally
  # routable per ssrf_filter's own blacklist. Does NOT make an HTTP
  # request.
  def self.allowed?(url)
    uri = parse_uri(url)
    return false unless uri

    addresses_for(uri.host).any? { |ip| globally_routable?(ip) }
  rescue URI::InvalidURIError, IPAddr::InvalidAddressError, Resolv::ResolvError
    false
  end

  def self.parse_uri(url)
    uri = URI(url.to_s)
    return nil unless %w[http https].include?(uri.scheme)
    return nil if uri.host.blank?

    uri
  rescue URI::InvalidURIError
    nil
  end

  def self.addresses_for(host)
    return [IPAddr.new(host)] if literal_ip?(host)

    Resolv.getaddresses(host).map { |a| IPAddr.new(a) }
  rescue Resolv::ResolvError, IPAddr::InvalidAddressError
    []
  end

  def self.literal_ip?(host)
    IPAddr.new(host)
    true
  rescue IPAddr::InvalidAddressError
    false
  end

  # Delegates to ssrf_filter's own blacklists so this validator's view of
  # "routable" matches what the gem will allow at fetch time. The lists
  # cover all the meaningful ranges (RFC1918, loopback, link-local,
  # CGNAT, IETF reserved, IPv6 ULA, multicast, IPv4-mapped IPv6, 6to4
  # back-references, etc.).
  def self.globally_routable?(ip)
    if ip.ipv4?
      SsrfFilter::IPV4_BLACKLIST.none? { |range| range.include?(ip) }
    elsif ip.ipv6?
      SsrfFilter::IPV6_BLACKLIST.none? { |range| range.include?(ip) }
    else
      false
    end
  end

  def self.fetch(verb, url, headers:)
    raw =
      SsrfFilter.public_send(
        verb,
        url.to_s,
        max_redirects: MAX_REDIRECTS,
        scheme_whitelist: %w[http https],
        headers: headers,
        http_options: HTTP_OPTIONS,
        on_cross_origin_redirect: :strip
      )

    body = raw.body.to_s
    if body.bytesize > MAX_BODY_BYTES
      raise ResponseTooLarge, "Response exceeded #{MAX_BODY_BYTES} bytes"
    end

    response = Response.new(raw.code.to_i, headers_hash(raw), body, raw.uri.to_s)

    raise_for_status!(response)
    response
  rescue SsrfFilter::Error, URI::InvalidURIError => e
    raise BlockedError, e.message
  rescue Timeout::Error => e
    raise Faraday::TimeoutError, e.message
  rescue SocketError,
         Errno::ECONNREFUSED,
         Errno::ECONNRESET,
         Errno::EHOSTUNREACH,
         Errno::ETIMEDOUT,
         Errno::ENETUNREACH,
         Errno::EPIPE,
         OpenSSL::SSL::SSLError,
         IOError,
         EOFError,
         Net::HTTPBadResponse,
         Net::ProtocolError => e
    raise Faraday::ConnectionFailed, e.message
  end

  # Mirror Faraday's `raise_error` middleware so callers that match on
  # specific subclasses (e.g. ProcessInkReviewSubmission's 403 carve-out)
  # keep working.
  def self.raise_for_status!(response)
    case response.status
    when 200..399
      nil
    when 400
      raise Faraday::BadRequestError.new(nil, response.to_h)
    when 401
      raise Faraday::UnauthorizedError.new(nil, response.to_h)
    when 403
      raise Faraday::ForbiddenError.new(nil, response.to_h)
    when 404
      raise Faraday::ResourceNotFound.new(nil, response.to_h)
    when 408
      raise Faraday::RequestTimeoutError.new(nil, response.to_h)
    when 409
      raise Faraday::ConflictError.new(nil, response.to_h)
    when 422
      raise Faraday::UnprocessableContentError.new(nil, response.to_h)
    when 429
      raise Faraday::TooManyRequestsError.new(nil, response.to_h)
    when 400..499
      raise Faraday::ClientError.new(nil, response.to_h)
    when 500..599
      raise Faraday::ServerError.new(nil, response.to_h)
    else
      raise Faraday::Error, "Unexpected status #{response.status}"
    end
  end

  # Net::HTTPResponse exposes headers as #each_header / #[]; convert to a
  # plain hash with downcased keys to match Faraday's response.headers
  # semantics.
  def self.headers_hash(raw)
    hash = {}
    raw.each_header { |k, v| hash[k.to_s.downcase] = v }
    hash
  end
end
