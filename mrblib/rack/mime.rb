module Rack
  module Mime
    MIME_TYPES = {
      ".txt" => "text/plain",
      ".html" => "text/html",
      ".htm" => "text/html",
      ".json" => "application/json",
      ".js" => "application/javascript",
      ".css" => "text/css",
      ".xml" => "application/xml",
      ".png" => "image/png",
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".svg" => "image/svg+xml",
      ".wasm" => "application/wasm"
    }

    module_function

    def mime_type(extension, fallback = nil)
      text = extension.to_s
      MIME_TYPES[text.start_with?(".") ? text : ".#{text}"] || fallback
    end
  end
end
