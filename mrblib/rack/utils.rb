module Rack
  module Utils
    STATUS_CODES = {
      continue: 100,
      ok: 200,
      created: 201,
      no_content: 204,
      moved_permanently: 301,
      found: 302,
      see_other: 303,
      not_modified: 304,
      bad_request: 400,
      unauthorized: 401,
      forbidden: 403,
      not_found: 404,
      method_not_allowed: 405,
      unprocessable_entity: 422,
      internal_server_error: 500
    }

    STATUS_WITH_NO_ENTITY_BODY = { 100 => true, 101 => true, 102 => true, 103 => true, 204 => true, 304 => true }
    HTML_ESCAPE = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;", "'" => "&#x27;" }

    class ParameterTypeError < TypeError; end
    class InvalidParameterError < ArgumentError; end

    module_function

    def status_code(status)
      return status if status.is_a?(Integer) && status >= 100 && status < 600

      code = STATUS_CODES[status.respond_to?(:to_sym) ? status.to_sym : status]
      return code if code

      raise ArgumentError, "Invalid response status: #{status.inspect}"
    end

    def escape_html(string)
      string.to_s.gsub(/[&<>"']/) { |character| HTML_ESCAPE[character] }
    end

    def escape(string)
      string.to_s.bytes.map do |byte|
        character = byte.chr
        if character =~ /[A-Za-z0-9\-._~]/
          character
        else
          hex = byte.to_s(16).upcase
          "%#{hex.bytesize == 1 ? "0#{hex}" : hex}"
        end
      end.join
    end

    def unescape(string)
      string.to_s.tr("+", " ").gsub(/%([0-9A-Fa-f]{2})/) do |encoded|
        encoded[1, 2].to_i(16).chr
      end
    end

    def parse_query(query)
      parse_nested_query(query)
    end

    def parse_nested_query(query)
      params = {}
      query.to_s.split(/[&;]/).each do |part|
        next if part.empty?

        key, value = part.split("=", 2)
        normalize_params(params, parse_key(unescape(key)), unescape(value || ""))
      end
      params
    end

    def build_query(params)
      params.map do |key, value|
        if value.is_a?(Array)
          value.map { |item| "#{escape(key)}[]=#{escape(item)}" }.join("&")
        else
          "#{escape(key)}=#{escape(value)}"
        end
      end.join("&")
    end

    def normalize_params(params, keys, value)
      key = keys.shift
      raise InvalidParameterError, "empty parameter key" if key.nil? || key.empty?

      if keys.empty?
        return assign_scalar(params, key, value)
      end

      child = keys.first
      if child.empty?
        array = params[key] ||= []
        raise ParameterTypeError, "expected Array for #{key}" unless array.is_a?(Array)

        if keys.length == 1
          array << value
        else
          hash = {}
          array << hash
          normalize_params(hash, keys[1..-1], value)
        end
      else
        hash = params[key] ||= {}
        raise ParameterTypeError, "expected Hash for #{key}" unless hash.is_a?(Hash)

        normalize_params(hash, keys, value)
      end
      params
    end

    def parse_key(key)
      first = key.index("[")
      return [key] unless first

      keys = [key[0, first]]
      remaining = key[first..-1]
      until remaining.empty?
        break unless remaining.start_with?("[")

        closing = remaining.index("]")
        raise InvalidParameterError, "malformed query parameter" unless closing

        keys << remaining[1, closing - 1]
        remaining = remaining[(closing + 1)..-1] || ""
      end
      raise InvalidParameterError, "malformed query parameter" unless remaining.empty?

      keys
    end

    def assign_scalar(params, key, value)
      current = params[key]
      if current.nil?
        params[key] = value
      elsif current.is_a?(Hash)
        raise ParameterTypeError, "expected scalar for #{key}"
      else
        params[key] = value
      end
      params
    end
  end
end
