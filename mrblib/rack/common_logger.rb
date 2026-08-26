module Rack
  # Logging is intentionally opt-in. Cloudflare Workers should use the host
  # logger; this middleware only makes a supplied logger available to apps.
  class CommonLogger
    def initialize(app, logger = nil)
      @app = app
      @logger = logger
    end

    def call(env)
      env[RACK_LOGGER] ||= @logger if @logger
      @app.call(env)
    end
  end
end
