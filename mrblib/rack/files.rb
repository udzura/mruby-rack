module Rack
  class Files
    class BaseIterator
      def initialize(path)
        @path = path
      end

      def each
        yield File.read(@path)
      end

      def close
        nil
      end
    end

    def initialize(root)
      @root = root
    end

    def serving(_request, path)
      body = BaseIterator.new(path)
      [200, Headers[CONTENT_LENGTH, File.size(path).to_s, CONTENT_TYPE, Mime.mime_type(File.extname(path), "application/octet-stream")], body]
    end

    def call(env)
      path = File.join(@root, Request.new(env).path_info)
      serving(nil, path)
    rescue Errno::ENOENT
      [404, Headers[CONTENT_TYPE, "text/plain", CONTENT_LENGTH, "9"], ["Not Found"]]
    end
  end
end
