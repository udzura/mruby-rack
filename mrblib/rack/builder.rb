module Rack
  class Builder
    def self.app(default_app = nil, &block)
      new(default_app, &block).to_app
    end

    def initialize(default_app = nil, **_options, &block)
      @middleware = []
      @app = default_app
      instance_eval(&block) if block_given?
    end

    def use(middleware, *arguments, **options, &block)
      @middleware << [middleware, arguments, options, block]
      nil
    end

    def run(app = nil, &block)
      raise ArgumentError, "Both app and block given" if app && block_given?

      @app = app || block
      nil
    end

    def to_app
      raise ArgumentError, "missing run statement" unless @app

      app = @app
      @middleware.reverse_each do |entry|
        middleware, arguments, options, block = entry
        app = middleware.new(app, *arguments, **options, &block)
      end
      app
    end

    def call(env)
      to_app.call(env)
    end
  end
end
