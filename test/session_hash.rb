def assert_session_hash(message, condition)
  raise message unless condition
end

options = {}
session = Rack::Session::Abstract::SessionHash.new({ x: 1, "y" => 2 }, "id", options)
assert_session_hash("Hash subclass", session.is_a?(Hash))
assert_session_hash("string/symbol lookup", session[:x] == 1 && session["x"] == 1 && session.key?(:x))
assert_session_hash("string keys", session.keys == ["x", "y"])
assert_session_hash("fetch and dig", session.fetch(:x) == 1 && session.dig(:y) == 2)

session.update(z: 3)
session.replace(w: 4)
assert_session_hash("update and replace normalize", session.keys == ["w"] && session[:w] == 4)
session.delete(:w)
assert_session_hash("delete normalizes", session.empty?)
assert_session_hash("per-request options", session.options.equal?(options))
puts "mruby-rack session hash: PASS"
