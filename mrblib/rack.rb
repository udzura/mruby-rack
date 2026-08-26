module Rack
  VERSION = [3, 2, 0]
  RELEASE = VERSION.join(".")

  HTTP_HOST = "HTTP_HOST"
  HTTPS = "HTTPS"
  PATH_INFO = "PATH_INFO"
  REQUEST_METHOD = "REQUEST_METHOD"
  SCRIPT_NAME = "SCRIPT_NAME"
  QUERY_STRING = "QUERY_STRING"
  SERVER_NAME = "SERVER_NAME"
  SERVER_PORT = "SERVER_PORT"

  CACHE_CONTROL = "cache-control"
  CONTENT_LENGTH = "content-length"
  CONTENT_TYPE = "content-type"
  SET_COOKIE = "set-cookie"
  TRANSFER_ENCODING = "transfer-encoding"

  GET = "GET"
  POST = "POST"
  PUT = "PUT"
  PATCH = "PATCH"
  DELETE = "DELETE"
  HEAD = "HEAD"
  OPTIONS = "OPTIONS"
  LINK = "LINK"
  UNLINK = "UNLINK"
  TRACE = "TRACE"

  RACK_ERRORS = "rack.errors"
  RACK_LOGGER = "rack.logger"
  RACK_INPUT = "rack.input"
  RACK_SESSION = "rack.session"
  RACK_SESSION_OPTIONS = "rack.session.options"
  RACK_URL_SCHEME = "rack.url_scheme"
  RACK_REQUEST_FORM_HASH = "rack.request.form_hash"
  RACK_REQUEST_QUERY_HASH = "rack.request.query_hash"
  RACK_REQUEST_QUERY_STRING = "rack.request.query_string"
  RACK_METHODOVERRIDE_ORIGINAL_METHOD = "rack.methodoverride.original_method"
end
