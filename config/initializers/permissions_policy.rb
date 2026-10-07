# Rails' permissions_policy DSL still emits the legacy Feature-Policy header.
Rails.application.config.action_dispatch.default_headers[
  "Permissions-Policy"
] = "camera=(), microphone=(), geolocation=(), payment=(), usb=()"
