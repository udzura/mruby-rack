def assert_cookie_simple(message, condition)
  raise message unless condition
end

secret = "s" * 32
empty_app = ->(_env) { [200, {}, ["ok"]] }
RUBY_DESCRIPTION = MRUBY_DESCRIPTION unless Object.const_defined?("RUBY_DESCRIPTION")

begin
  Rack::Session::CookieSimple.new(empty_app, secret: secret)
  raise "missing Crypto was accepted"
rescue NameError => error
  assert_cookie_simple("Crypto constant check", error.message.include?("Crypto"))
end

# Reversible test double for the PicoRuby Worker AES-GCM API.
module Crypto
  class << self
    attr_reader :last_algorithm, :last_secret, :last_iv

    def encrypt(algorithm, secret, raw_data)
      @last_algorithm = algorithm
      @last_secret = secret
      @last_iv = Random.bytes(12)
      [@last_iv, secret + raw_data.reverse + "tag"]
    end

    def decrypt(algorithm, secret, iv, encrypted)
      raise "authentication failed" unless algorithm == :AES_GCM
      raise "authentication failed" unless encrypted.start_with?(secret) && encrypted.end_with?("tag")
      raise "invalid IV" unless iv.bytesize == 12

      encrypted[secret.bytesize, encrypted.bytesize - secret.bytesize - 3].reverse
    end
  end
end

begin
  Rack::Session::CookieSimple.new(empty_app, secret: "short")
  raise "short secret was accepted"
rescue ArgumentError => error
  assert_cookie_simple("secret length check", error.message.include?("32-byte"))
end

seen = []
sessions = []
app = Rack::Session::CookieSimple.new(lambda do |env|
  session = env["rack.session"]
  seen << session.to_hash
  sessions << session
  assert_cookie_simple("secret kept private", !env["rack.session.options"].key?(:secret))
  session[:count] = session.fetch(:count, 0) + 1
  [200, {}.freeze, ["ok"]]
end, secret: secret)

first = app.call({})
cookie = first[1]["set-cookie"].split(";", 2).first
cookie_value = Rack::Utils.unescape(cookie.split("=", 2)[1])
assert_cookie_simple("AES-GCM algorithm", Crypto.last_algorithm == :AES_GCM)
assert_cookie_simple("secret passed to Crypto", Crypto.last_secret == secret)
assert_cookie_simple("12-byte IV", Crypto.last_iv.bytesize == 12)
assert_cookie_simple("cookie contains IV", cookie_value[0, 12] == Crypto.last_iv)

second = app.call({ "HTTP_COOKIE" => cookie })
assert_cookie_simple("round trip", seen[1]["count"] == 1)
assert_cookie_simple("session ID persisted", seen[1]["session_id"].is_a?(String))
assert_cookie_simple("logical session ID exposed", sessions[0].id == seen[1]["session_id"])
assert_cookie_simple("second write", second[1]["set-cookie"].is_a?(String))

tampered = cookie_value.dup
tampered[-1] = tampered[-1] == "x" ? "y" : "x"
app.call({ "HTTP_COOKIE" => "rack.session=#{Rack::Utils.escape(tampered)}" })
assert_cookie_simple("tampered cookie discarded", seen[2].empty?)

wrong_secret_session = nil
wrong_secret_app = Rack::Session::CookieSimple.new(lambda do |env|
  wrong_secret_session = env["rack.session"].to_hash
  [200, {}, ["ok"]]
end, secret: "x" * 32)
wrong_secret_app.call({ "HTTP_COOKIE" => cookie })
assert_cookie_simple("wrong secret discarded", wrong_secret_session.empty?)

puts "mruby-rack cookie simple: PASS"
