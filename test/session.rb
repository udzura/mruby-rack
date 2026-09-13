class MemorySessionStore < Rack::Session::Abstract::Persisted
  attr_reader :records
  def initialize(app, options = {})
    super
    @records = {}
    @sequence = 0
  end
  private
  def generate_sid
    @sequence += 1
    "test#{@sequence}"
  end
  def find_session(req, sid)
    @records.key?(sid) ? [sid, @records[sid].dup] : [nil, {}]
  end
  def write_session(req, sid, data, options)
    @records[sid] = data.to_hash
    sid
  end
  def delete_session(req, sid, options)
    @records.delete(sid)
    options[:drop] ? nil : generate_sid
  end
end

def assert_session(message, condition)
  raise message unless condition
end

app = MemorySessionStore.new(lambda do |env|
  session = env["rack.session"]
  assert_session("Hash session", session.is_a?(Hash))
  session.merge!({ count: session.fetch(:count, 0) + 1 })
  assert_session("string keys", session.keys == ["count"])
  [200, {}.freeze, ["ok"]]
end)
first = app.call({})
sid = first[1]["set-cookie"].split(";", 2).first
app.call({ "HTTP_COOKIE" => sid })
assert_session("round trip", app.records["test1"]["count"] == 2)
puts "mruby-rack sessions: PASS"
