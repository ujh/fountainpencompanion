# frozen_string_literal: true
Kaminari.configure do |config|
  # config.default_per_page = 25
  # Global ceiling on `page[size]` (the user-supplied per-page value).
  # Per-model `max_paginates_per` overrides this for tighter caps.
  config.max_per_page = 500
  # config.window = 4
  # config.outer_window = 0
  # config.left = 0
  # config.right = 0
  # config.page_method_name = :page
  # config.param_name = :page
  # config.params_on_first_page = false
end
