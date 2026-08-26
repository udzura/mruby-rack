MRuby::Gem::Specification.new("mruby-rack") do |spec|
  spec.license = "MIT"
  spec.author = "Kondo Uchio"
  spec.summary = "Minimal Rack 3 API for mruby and PicoRuby"
  spec.version = "0.1.0"

  %w[
    mruby-array-ext
    mruby-hash-ext
    mruby-kernel-ext
    mruby-numeric-ext
    mruby-object-ext
    mruby-regexp
    mruby-string-ext
  ].each do |name|
    spec.add_dependency name
  end

  spec.rbfiles = [File.join(dir, "mrblib", "rack.rb")] +
    Dir[File.join(dir, "mrblib", "rack", "*.rb")].sort
end
