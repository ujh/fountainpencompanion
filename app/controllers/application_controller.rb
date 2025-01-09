class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  around_action :set_time_zone
  before_action :save_user_agent

  unless Rails.env.development?
    rescue_from ActionView::MissingTemplate do |_exception|
      render file: "public/404.html", status: :not_found, layout: false
    end
  end

  private

  def set_time_zone(&)
    if current_user && current_user.time_zone.present?
      Time.use_zone(current_user.time_zone, &)
    else
      yield
    end
  end

  USER_AGENT_PARSER =
    UserAgentParser::Parser.new(
      patterns_paths: [
        Rails.root.join("config/user_agents.yml"),
        UserAgentParser::DefaultPatternsPath
      ]
    )

  def save_user_agent
    user_agent = request.user_agent
    UserAgent.create(
      name: USER_AGENT_PARSER.parse(user_agent).family,
      raw_name: user_agent,
      day: Date.current
    )
  end
end
