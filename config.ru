# This file is used by Rack-based servers to start the application.

require "./config/environment"

run Rails.application
Rails.application.load_server
