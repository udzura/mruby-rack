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
- `Rack::Mime`, a small `Rack::Files`, and a plain-text `Rack::ShowExceptions`

The initial target supports buffered, `application/x-www-form-urlencoded`
request bodies. It does not provide Rackup/config.ru evaluation, multipart
forms, sessions/cookies, streaming/hijacking, Rack::Lint, or the separate
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
