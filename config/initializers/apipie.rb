Apipie.configure do |config|
  config.app_name = "Fountainpencompanion"
  config.api_base_url = "/api"
  config.doc_base_url = "/api-docs"
  # where is your API defined?
  config.api_controllers_matcher = "#{Rails.root}/app/controllers/**/*.rb"

  config.app_info = <<-EOS
    To access the API, you need to authenticate using an API token.
    You can include the token in your requests by adding an Authorization header with the value "Bearer YOUR_API_TOKEN".
    API tokens can be generated in your account settings.

    At this point the API isn't fully fledged and cannot to everything the web app can do, but it is under active development.
    If there is something you need that isn't currently supported, please get in touch!

    Note that there is a rate limit for the API and please bear in mind that this is a hobby project with limited
    resources to serve requests. Please don't abuse it! 💚
  EOS
end
