# Be sure to restart your server when you modify this file.

# See https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails.application.configure do
  hcaptcha = %w[https://hcaptcha.com https://*.hcaptcha.com]
  clicky = %w[https://static.getclicky.com https://in.getclicky.com]

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.frame_ancestors :self
    policy.script_src :self, *clicky, *hcaptcha
    policy.style_src :self, :unsafe_inline, *hcaptcha
    policy.font_src :self, :data
    policy.img_src :self, :data, :https, :http
    policy.connect_src :self, "https://api.honeybadger.io", "https://in.getclicky.com", *hcaptcha
    policy.frame_src(*hcaptcha)
    policy.report_uri "/csp-reports"
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_report_only = true
end
