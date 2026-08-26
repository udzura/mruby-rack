module Rack
  class MethodOverride
    ALLOWED_METHODS = [PUT, PATCH, DELETE]

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Request.new(env)
      if request.post?
        method = request.params["_method"].to_s.upcase
        if ALLOWED_METHODS.include?(method)
          env[RACK_METHODOVERRIDE_ORIGINAL_METHOD] = env[REQUEST_METHOD]
          env[REQUEST_METHOD] = method
        end
      end
      @app.call(env)
    end
  end
end
