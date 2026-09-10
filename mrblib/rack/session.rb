module Rack
  module Session
    module Abstract
      # Eager, string-keyed session data. Nested values remain ordinary Ruby data.
      class SessionHash < Hash
        attr_accessor :id
        attr_reader :options

        def initialize(data, id, options)
          super()
          @id, @options = id, options
          update(data)
        end

        def [](key); super(key.to_s) end
        def []=(key, value); super(key.to_s, value) end
        alias store []=
        def fetch(key, *args, &block); super(key.to_s, *args, &block) end
        def delete(key, &block); super(key.to_s, &block) end
        def key?(key); super(key.to_s) end
        def dig(key, *keys); super(key.to_s, *keys) end
        alias has_key? key?
        alias include? key?
        alias member? key?

        def update(data)
          data.each { |key, value| self[key] = value }
          self
        end
        alias merge! update

        def replace(data)
          return self if equal?(data)
          clear
          update(data)
        end

        def to_hash
          {}.merge(self)
        end
      end

      # Small cookie-only Persisted interface for mruby backends. Subclasses
      # implement find_session, write_session, delete_session and generate_sid.
      class Persisted
        DEFAULT_OPTIONS = {
          key: "rack.session", path: "/", domain: nil, secure: false,
          httponly: true, same_site: :lax, expire_after: nil
        }.freeze
        attr_reader :key, :default_options

        def initialize(app, options = {})
          @app = app
          @default_options = DEFAULT_OPTIONS.merge(options)
          @key = @default_options[:key]
          validate_cookie_options(@default_options)
        end

        def call(env)
          req = Rack::Request.new(env)
          options = @default_options.dup
          incoming = req.cookies[@key]
          sid, data = find_session(req, incoming)
          snapshot = session_snapshot(data)
          session = SessionHash.new(data, sid, options)
          env[RACK_SESSION] = session
          env[RACK_SESSION_OPTIONS] = options
          options[:id] = sid
          status, headers, body = @app.call(env)
          headers = headers.dup
          unless options[:skip] || (options[:secure] && !req.ssl?)
            validate_cookie_options(options)
            if options[:drop]
              delete_session(req, sid, options) if sid
              append_cookie(headers, "", options, true)
              session.id = options[:id] = nil
            else
              if options[:renew]
                sid = delete_session(req, sid, options)
              end
              data = env[RACK_SESSION]
              if options[:renew] || session_changed?(snapshot, data)
                unless data.empty? && sid.nil?
                  sid ||= generate_sid
                  saved = write_session(req, sid, data, options)
                  raise RuntimeError, "session write failed" unless saved
                  sid = saved_session_id(saved)
                  session.id = options[:id] = sid
                  append_cookie(headers, session_cookie_value(saved), options) unless options[:defer] && !options[:renew]
                end
              end
            end
          end
          [status, headers, body]
        rescue Exception
          body.close if body && body.respond_to?(:close)
          raise
        end

        private

        def session_snapshot(data); nil end
        def session_changed?(snapshot, data); true end
        def generate_sid; raise NotImplementedError, "backend must supply secure session IDs" end
        def find_session(req, sid); raise NotImplementedError end
        def write_session(req, sid, data, options); raise NotImplementedError end
        def delete_session(req, sid, options); raise NotImplementedError end
        def saved_session_id(saved); saved end
        def session_cookie_value(saved); saved end

        def validate_cookie_options(options)
          unless @key.is_a?(String) && @key =~ /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/
            raise ArgumentError, "invalid session cookie name"
          end
          [:path, :domain].each do |name|
            value = options[name]
            if value && (!value.is_a?(String) || value =~ /[\x00-\x20\x7f;,]/)
              raise ArgumentError, "invalid cookie #{name}"
            end
          end
          same_site = options[:same_site]
          unless same_site.nil? || [:lax, :strict, :none].include?(same_site)
            raise ArgumentError, "same_site must be :lax, :strict, :none or nil"
          end
          if same_site == :none && !options[:secure]
            raise ArgumentError, "SameSite=None requires secure: true"
          end
          ttl = options[:expire_after]
          if ttl && (!ttl.is_a?(Integer) || ttl <= 0)
            raise ArgumentError, "expire_after must be a positive integer or nil"
          end
        end

        def append_cookie(headers, sid, options, expired = false)
          cookie = "#{@key}=#{Rack::Utils.escape(sid)}"
          cookie += "; Path=#{options[:path]}" if options[:path]
          cookie += "; Domain=#{options[:domain]}" if options[:domain]
          if expired
            cookie += "; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
          elsif options[:expire_after]
            cookie += "; Max-Age=#{options[:expire_after]}"
          end
          cookie += "; Secure" if options[:secure]
          cookie += "; HttpOnly" if options[:httponly]
          cookie += "; SameSite=#{options[:same_site].to_s.capitalize}" if options[:same_site]
          existing = headers[SET_COOKIE]
          headers[SET_COOKIE] = existing ? (existing.is_a?(Array) ? existing + [cookie] : [existing, cookie]) : cookie
        end
      end
    end

    # Encrypted, JSON-serialized cookie sessions for PicoRuby Worker runtimes.
    class CookieSimple < Abstract::Persisted
      IV_SIZE = 12
      SECRET_SIZE = 32

      def initialize(app, options = {})
        %w[SecureRandom Crypto JSON].each do |name|
          unless Object.const_defined?(name)
            raise NameError, "#{name} is required by Rack::Session::CookieSimple"
          end
        end

        @secret = options[:secret]
        unless @secret.is_a?(String) && @secret.bytesize == SECRET_SIZE
          raise ArgumentError, "secret must be a 32-byte String"
        end

        public_options = options.dup
        public_options.delete(:secret)
        super(app, public_options)
      end

      private

      def generate_sid
        SecureRandom.random_bytes(16).bytes.map do |byte|
          hex = byte.to_s(16)
          hex.bytesize == 1 ? "0#{hex}" : hex
        end.join
      end

      def find_session(req, cookie)
        return [nil, {}] unless cookie && cookie.bytesize > IV_SIZE

        iv = cookie[0, IV_SIZE]
        encrypted = cookie[IV_SIZE, cookie.bytesize - IV_SIZE]
        data = JSON.parse(Crypto.decrypt(:AES_GCM, @secret, iv, encrypted))
        return [nil, {}] unless data.is_a?(Hash)

        sid = data["session_id"]
        sid.is_a?(String) ? [sid, data] : [nil, {}]
      rescue StandardError
        [nil, {}]
      end

      def write_session(req, sid, data, options)
        raw_data = JSON.generate(data.to_hash.merge("session_id" => sid))
        iv, encrypted = Crypto.encrypt(:AES_GCM, @secret, raw_data)
        unless iv.is_a?(String) && iv.bytesize == IV_SIZE && encrypted.is_a?(String)
          raise RuntimeError, "Crypto.encrypt returned an invalid AES-GCM result"
        end

        cookie = iv + encrypted
        return nil if Rack::Utils.escape(cookie).bytesize > 4096 - @key.bytesize

        [sid, cookie]
      end

      def delete_session(req, sid, options)
        options[:drop] ? nil : generate_sid
      end

      def session_snapshot(data)
        JSON.generate(data)
      end

      def session_changed?(snapshot, data)
        snapshot != JSON.generate(data)
      end

      def saved_session_id(saved)
        saved[0]
      end

      def session_cookie_value(saved)
        saved[1]
      end
    end
  end
end
