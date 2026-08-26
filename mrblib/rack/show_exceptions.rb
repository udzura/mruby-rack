module Rack
  class ShowExceptions
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Exception => error
      errors = env[RACK_ERRORS]
      errors.puts(error.message) if errors && errors.respond_to?(:puts)
      body = "Internal Server Error"
      [500, Headers[CONTENT_TYPE, "text/plain", CONTENT_LENGTH, body.bytesize.to_s], [body]]
    end
  end
end
