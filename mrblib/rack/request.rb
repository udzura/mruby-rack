module Rack
  class Request
    DEFAULT_PORTS = { "http" => 80, "https" => 443, "ws" => 80, "wss" => 443 }
    FORM_METHODS = [POST, PUT, PATCH]

    attr_reader :env

    def initialize(env)
      @env = env
    end

    def get_header(name); env[name] end
    def set_header(name, value); env[name] = value end
    def fetch_header(name, &block); env.fetch(name, &block) end
    def delete_header(name); env.delete(name) end

    def body; get_header(RACK_INPUT) end
    def cookies
      Utils.parse_cookies_header(get_header("HTTP_COOKIE"))
    end

    def script_name; get_header(SCRIPT_NAME).to_s end
    def script_name=(value); set_header(SCRIPT_NAME, value.to_s) end
    def path_info; get_header(PATH_INFO).to_s end
    def path_info=(value); set_header(PATH_INFO, value.to_s) end
    def request_method; get_header(REQUEST_METHOD).to_s end
    def query_string; get_header(QUERY_STRING).to_s end
    def content_length; get_header("CONTENT_LENGTH") end
    def content_type; get_header("CONTENT_TYPE").to_s.split(";", 2).first end
    def logger; get_header(RACK_LOGGER) end
    def user_agent; get_header("HTTP_USER_AGENT") end
    def referer; get_header("HTTP_REFERER") end
    alias referrer referer

    def get?; request_method == GET end
    def post?; request_method == POST end
    def put?; request_method == PUT end
    def patch?; request_method == PATCH end
    def delete?; request_method == DELETE end
    def head?; request_method == HEAD end
    def options?; request_method == OPTIONS end
    def trace?; request_method == TRACE end
    def link?; request_method == LINK end
    def unlink?; request_method == UNLINK end

    def safe?
      get? || head? || options? || trace?
    end

    def scheme
      return "https" if get_header(HTTPS) == "on"

      forwarded_scheme || get_header(RACK_URL_SCHEME).to_s
    end

    def ssl?
      scheme == "https" || scheme == "wss"
    end
    alias secure? ssl?

    def forwarded?
      !forwarded_authority.nil?
    end

    def authority
      forwarded_authority || get_header(HTTP_HOST) || server_authority
    end

    def host
      split_authority(authority)[0]
    end

    def hostname
      host.delete_prefix("[").delete_suffix("]")
    end

    def port
      split_authority(authority)[1] || get_header(SERVER_PORT).to_i.nonzero? || DEFAULT_PORTS[scheme] || 80
    end

    def host_with_port
      return host if port == DEFAULT_PORTS[scheme]

      "#{host}:#{port}"
    end

    def session
      env[RACK_SESSION] ||= {}
    end

    def session_options
      env[RACK_SESSION_OPTIONS] ||= {}
    end

    def query_params
      query = query_string
      if env[RACK_REQUEST_QUERY_STRING] != query
        env[RACK_REQUEST_QUERY_HASH] = Utils.parse_nested_query(query)
        env[RACK_REQUEST_QUERY_STRING] = query
      end
      env[RACK_REQUEST_QUERY_HASH] || {}
    end

    def form_params
      return {} unless FORM_METHODS.include?(request_method)
      return {} unless content_type == "application/x-www-form-urlencoded"

      input = body
      return {} unless input && input.respond_to?(:read)

      input.rewind if input.respond_to?(:rewind)
      data = input.read.to_s
      input.rewind if input.respond_to?(:rewind)
      Utils.parse_nested_query(data)
    end

    def params
      query_params.merge(form_params)
    end

    private

    def forwarded_scheme
      value = get_header("HTTP_X_FORWARDED_PROTO") || get_header("HTTP_X_FORWARDED_SCHEME")
      value.to_s.split(",").last.to_s.strip unless value.nil?
    end

    def forwarded_authority
      value = get_header("HTTP_X_FORWARDED_HOST")
      value.to_s.split(",").last.to_s.strip unless value.nil?
    end

    def server_authority
      name = get_header(SERVER_NAME)
      return nil if name.nil? || name.empty?

      port = get_header(SERVER_PORT)
      port && !port.empty? ? "#{name}:#{port}" : name
    end

    def split_authority(value)
      text = value.to_s.strip
      return ["", nil] if text.empty?

      if text.start_with?("[")
        closing = text.index("]")
        return [text, nil] unless closing
        host = text[0..closing]
        suffix = text[(closing + 1)..-1].to_s
        return [host, suffix[1..-1].to_i] if suffix.start_with?(":")
        return [host, nil]
      end

      colon = text.rindex(":")
      if colon && text[(colon + 1)..-1] =~ /\A\d+\z/
        [text[0...colon], text[(colon + 1)..-1].to_i]
      else
        [text, nil]
      end
    end
  end
end
