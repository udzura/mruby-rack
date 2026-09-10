# mruby-rack

An intentionally small Rack 3-compatible core for mruby and PicoRuby. It is
designed to provide the Rack classes exercised by a basic `Sinatra::Base`
application, not to replicate all Rack middleware and server features.

## Included API

- `Rack::Headers` with lowercase response-header normalization
- `Rack::Utils` status handling, HTML/URL escaping, and urlencoded query parsing
- `Rack::Request` request metadata, query/form parameters, host, and scheme
- `Rack::Response` buffered responses and content-length generation
- `Rack::Builder`, `Rack::Head`, `Rack::MethodOverride`, and `Rack::CommonLogger`
- `Rack::Session::Abstract::Persisted`, a minimal cookie-based session backend interface,
  and `Rack::Session::CookieSimple`, an AES-256-GCM encrypted cookie store
- `Rack::Mime`, a small `Rack::Files`, and a plain-text `Rack::ShowExceptions`

The initial target supports buffered, `application/x-www-form-urlencoded`
request bodies. It does not provide Rackup/config.ru evaluation, multipart
forms, bundled session stores, streaming/hijacking, Rack::Lint, or the complete
`rack-protection` and `rack-session` gems.

`Rack::Headers` is deliberately lowercase-oriented so its output can be passed
to the PicoRuby Cloudflare Worker Rack adapter.

The exact Sinatra 4.2.1 boundary is documented in
[`docs/sinatra-4.2.1.md`](docs/sinatra-4.2.1.md).

## PicoRuby build

PicoRuby keeps mruby core gems beneath `picoruby-mruby`, so load the required
gems explicitly before this gem:

```ruby
mruby_core = "#{MRUBY_ROOT}/mrbgems/picoruby-mruby/lib/mruby/mrbgems"

%w[
  mruby-array-ext mruby-hash-ext mruby-kernel-ext mruby-numeric-ext
  mruby-object-ext mruby-regexp mruby-string-ext
].each { |name| conf.gem gemdir: "#{mruby_core}/#{name}" }

conf.gem github: "udzura/mruby-rack"
```

## Test

The smoke test builds a native PicoRuby `mruby` executable and exercises the
included request, response, and middleware path:

```console
PICORUBY_ROOT=/path/to/picoruby rake test
```

With the standard ghq checkout layout, the adjacent PicoRuby checkout is
detected automatically.

## Source reference

The API shape is based on Rack 3.2.7 (MIT). The implementation is a separate,
mruby-oriented port with only the features documented above.

## Session backends

`Rack::Session::Abstract::Persisted` is an eager, cookie-only subset of the
rack-session API. Subclasses implement `find_session(request, sid)`,
`write_session(request, sid, data, options)`, `delete_session(request, sid, options)`
and `generate_sid` (use a cryptographically secure source in production).
`find_session` returns `[sid, Hash]`, `write_session` returns the saved ID,
and `delete_session` returns a replacement ID for renewal or nil for dropping.
Unknown client IDs must never be adopted as new session IDs.

The initializer is `initialize(app, options = {})`. Each request receives a
string-keyed `Hash` subclass at `env["rack.session"]` and its own options at
`env["rack.session.options"]` (`Request#session_options`). Symbol access through
`[]`, `[]=`, `fetch`, `key?`, `dig`, `delete`, `update` and `replace` is supported.
Nested values remain ordinary Ruby values. Session data is loaded eagerly.

Supported options: `key`, `path`, `domain`, `secure`, `httponly`, `same_site`
(`:lax`, `:strict`, `:none` or nil), `expire_after` (Cookie Max-Age), `skip`,
`defer`, `renew`, and `drop`. Request options can be changed by the app. A drop
expires the cookie; renewal retains data and replaces the ID. Secure sessions
are committed only for HTTPS/WSS requests. Existing Set-Cookie values are
preserved using Rack 3 arrays. Backends may override `session_snapshot(data)`
and `session_changed?(snapshot, data)` to avoid unnecessary writes.

This is not a full rack-session port: lazy loading, SessionId/private ID hashing,
SessionHash#destroy, URL-based IDs, callable SameSite, partitioned cookies,
max_age, assume_ssl and the Context API are not implemented.

`Rack::Session::CookieSimple` stores the session Hash as encrypted JSON. It
requires `Random`, `JSON`, and the PicoRuby Worker `Crypto` API. Its `secret`
must be exactly 32 raw bytes for AES-256. `Crypto.encrypt` must generate a fresh
12-byte IV and return `[iv, encrypted]`, with the authentication tag included in
`encrypted`; `Crypto.decrypt` must reject authentication failures.

```ruby
use Rack::Session::CookieSimple,
  secret: Random.bytes(32),
  secure: true,
  httponly: true,
  same_site: :lax
```

Malformed, modified, or incorrectly encrypted cookies are discarded and start
an empty session. There is no plaintext or legacy-cookie fallback.
