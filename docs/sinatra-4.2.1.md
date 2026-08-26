# Sinatra 4.2.1 boundary

`mruby-rack` targets the Rack symbols used directly by
`sinatra/lib/sinatra/base.rb` in Sinatra 4.2.1:

| Sinatra use | mruby-rack support |
| --- | --- |
| `Rack::Request` | Request method, path, scheme, host, URL-encoded params, and session Hash access |
| `Rack::Response` / `Rack::Response::Helpers` | Buffered body, headers, status, `finish`, and common status predicates |
| `Rack::Utils` | `status_code`, `escape_html`, URL escaping, and nested query parsing |
| `Rack::Headers` | Lowercase header normalization suitable for the Worker adapter |
| `Rack::Builder`, `Rack::Head`, `Rack::MethodOverride`, `Rack::CommonLogger` | Basic middleware stack construction |
| `Rack::Files`, `Rack::Mime`, `Rack::ShowExceptions` | Minimal implementation for the names referenced by Sinatra |

The following are intentionally outside this gem because they are separate
Rack projects or are not useful in the initial Worker target:

- `rack-protection` (`Rack::Protection`)
- `rack-session` (`Rack::Session::Cookie`)
- Rackup / `config.ru`
- multipart parsing, cookie serialization, streaming/hijacking, and Rack::Lint

Sinatra 4.2.1 requires `rack-protection` and `rack-session` at load time, and
its default middleware setup uses `Rack::Protection`. The future minimal
Sinatra port therefore needs explicit no-op/disabled behavior for those
optional features; `mruby-rack` does not define their constants.
