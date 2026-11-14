Faraday.default_connection_options =
  Faraday.default_connection_options.merge(
    headers: {
      "User-Agent" => Fountainpencompanion::USER_AGENT
    }
  )
