module Rack
  # Rack 3 response headers use lowercase field names. This Hash subclass
  # normalizes access so applications can still use conventional title case.
  class Headers < Hash
    def self.[](*items)
      return new.merge!(items.first) if items.length == 1 && items.first.is_a?(Hash)
      raise ArgumentError, "odd number of arguments for Rack::Headers" if items.length.odd?

      result = new
      until items.empty?
        result[items.shift] = items.shift
      end
      result
    end

    def [](key)
      super(normalize(key))
    end

    def []=(key, value)
      super(normalize(key), value)
    end
    alias store []=

    def delete(key)
      super(normalize(key))
    end

    def fetch(key, *default, &block)
      super(normalize(key), *default, &block)
    end

    def key?(key)
      super(normalize(key))
    end
    alias has_key? key?
    alias include? key?
    alias member? key?

    def merge(other, &block)
      dup.merge!(other, &block)
    end

    def merge!(other, &block)
      other.each do |key, value|
        normalized = normalize(key)
        self[normalized] = block_given? && key?(normalized) ? yield(normalized, self[normalized], value) : value
      end
      self
    end
    alias update merge!

    def replace(other)
      clear
      merge!(other)
    end

    private

    def normalize(key)
      key.to_s.downcase
    end
  end
end
