require Rails.root.join("lib/json_body_limit").to_s

Rails.application.config.middleware.insert_before(Rack::Attack, JsonBodyLimit)
