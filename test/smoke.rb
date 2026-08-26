def assert(condition, message)
  raise "assertion failed: #{message}" unless condition
end

class Input
  def initialize(data)
    @data = data
    @offset = 0
  end

  def read
    value = @data[@offset..-1] || ""
    @offset = @data.bytesize
    value
  end

  def rewind
    @offset = 0
    0
  end
end

headers = Rack::Headers["Content-Type", "text/plain"]
headers["X-Request-Id"] = "abc"
assert(headers["content-type"] == "text/plain", "Headers downcase lookup")
assert(headers.key?("X-REQUEST-ID"), "Headers normalize key predicates")

params = Rack::Utils.parse_nested_query("name=Pico+Ruby&tag[]=wasm&tag[]=edge&user[name]=udzura")
assert(params == {
  "name" => "Pico Ruby",
  "tag" => ["wasm", "edge"],
  "user" => { "name" => "udzura" }
}, "nested query parsing")
assert(Rack::Utils.parse_nested_query("value=first&value=last") == { "value" => "last" }, "repeated scalar query parameter")
assert(Rack::Utils.escape_html("<p>&\"'</p>") == "&lt;p&gt;&amp;&quot;&#x27;&lt;/p&gt;", "HTML escaping")

env = {
  "REQUEST_METHOD" => "POST",
  "PATH_INFO" => "/hello",
  "SCRIPT_NAME" => "",
  "QUERY_STRING" => "from=query",
  "CONTENT_TYPE" => "application/x-www-form-urlencoded; charset=utf-8",
  "HTTP_HOST" => "example.com:8443",
  "rack.url_scheme" => "https",
  "rack.input" => Input.new("from=body&name=pico")
}
request = Rack::Request.new(env)
assert(request.post?, "request method")
assert(request.secure?, "request scheme")
assert(request.host == "example.com", "request host")
assert(request.port == 8443, "request port")
assert(request.params == { "from" => "body", "name" => "pico" }, "form params override query params")
assert(env["rack.input"].read == "from=body&name=pico", "form parsing rewinds input")

response = Rack::Response.new("Hello", :ok, "Content-Type" => "text/plain")
status, response_headers, body = response.finish
assert(status == 200, "response status")
assert(response_headers["content-length"] == "5", "response content length")
assert(body == ["Hello"], "response body")

empty_response = Rack::Response.new("ignored", :no_content, "Content-Type" => "text/plain")
status, response_headers, body = empty_response.finish
assert(status == 204 && body == [], "status without entity body")
assert(!response_headers.key?("content-type"), "status without entity headers")

class TraceMiddleware
  def initialize(app, name)
    @app = app
    @name = name
  end

  def call(env)
    env["trace"] << "before #{@name}"
    result = @app.call(env)
    env["trace"] << "after #{@name}"
    result
  end
end

builder = Rack::Builder.new
builder.use TraceMiddleware, "outer"
builder.use Rack::MethodOverride
builder.use Rack::Head
builder.run lambda { |current_env| [200, { "Content-Type" => "text/plain" }, [current_env["REQUEST_METHOD"]]] }
app = builder.to_app

override_env = {
  "REQUEST_METHOD" => "POST",
  "PATH_INFO" => "/",
  "QUERY_STRING" => "_method=DELETE",
  "trace" => []
}
status, response_headers, body = app.call(override_env)
assert(status == 200 && body == ["DELETE"], "middleware application")
assert(response_headers["Content-Type"] == "text/plain", "app headers remain usable")
assert(override_env["trace"] == ["before outer", "after outer"], "middleware order")

head_env = { "REQUEST_METHOD" => "HEAD", "PATH_INFO" => "/", "QUERY_STRING" => "", "trace" => [] }
_status, _headers, body = app.call(head_env)
assert(body == [], "Rack::Head strips HEAD bodies")
assert(Rack::Mime.mime_type("json") == "application/json", "mime lookup")

exception_app = Rack::ShowExceptions.new(lambda { |_current_env| raise "boom" })
status, _headers, body = exception_app.call({})
assert(status == 500 && body == ["Internal Server Error"], "plain show exceptions response")

puts "mruby-rack smoke: PASS"
