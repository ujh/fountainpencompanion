class FlyClientIp
  attr_accessor :app

  def initialize(app)
    self.app = app
  end

  def call(env)
    client_ip = env["HTTP_FLY_CLIENT_IP"]
    if client_ip.present?
      env["HTTP_X_FORWARDED_FOR"] = client_ip
      env.delete("HTTP_FORWARDED")
      env.delete("HTTP_CLIENT_IP")
    end
    app.call(env)
  end
end
