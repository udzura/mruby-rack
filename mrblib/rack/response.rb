module Rack
  class Response
    attr_accessor :status, :body, :length
    attr_reader :headers

    def self.[](status, headers, body)
      new(body, status, headers)
    end

    def initialize(body = nil, status = 200, headers = {})
      @status = Utils.status_code(status)
      @headers = Headers.new.merge!(headers)
      self.body = body.nil? ? [] : body
      @length = body.respond_to?(:to_str) ? body.to_str.bytesize : nil
      yield self if block_given?
    end

    def body=(value)
      @body = value.respond_to?(:to_str) ? [value.to_str] : value
    end

    def each(&block)
      body.each(&block)
    end

    def write(chunk)
      buffered_body << chunk.to_s
      @length = buffered_body.map(&:bytesize).reduce(0, :+)
      self
    end

    def close
      body.close if body.respond_to?(:close)
    end

    def get_header(key)
      headers[key]
    end
    alias [] get_header

    def set_header(key, value)
      headers[key] = value
    end
    alias []= set_header

    def delete_header(key)
      headers.delete(key)
    end

    def has_header?(key)
      headers.key?(key)
    end

    def finish
      if Utils::STATUS_WITH_NO_ENTITY_BODY[status]
        delete_header(CONTENT_TYPE)
        delete_header(CONTENT_LENGTH)
        close
        return [status, headers, []]
      end

      if body.is_a?(Array) && !headers.key?(CONTENT_LENGTH)
        headers[CONTENT_LENGTH] = body.map(&:bytesize).reduce(0, :+).to_s
      end
      [status, headers, body]
    end
    alias to_a finish

    module Helpers
      def informational?; status >= 100 && status < 200 end
      def successful?; status >= 200 && status < 300 end
      def redirection?; status >= 300 && status < 400 end
      def client_error?; status >= 400 && status < 500 end
      def server_error?; status >= 500 && status < 600 end
      def ok?; status == 200 end
      def not_found?; status == 404 end
      def content_type; self[CONTENT_TYPE] end
      def content_type=(value); self[CONTENT_TYPE] = value end
      def content_length; value = self[CONTENT_LENGTH]; value && value.to_i end
      def location; self["location"] end
      def location=(value); self["location"] = value end
    end

    include Helpers

    private

    def buffered_body
      return body if body.is_a?(Array)

      @body = body.respond_to?(:each) ? body.to_a : []
    end
  end
end
