require "rake"

PROJECT_ROOT = File.expand_path(__dir__)

def picoruby_root
  candidates = [
    ENV["PICORUBY_ROOT"],
    File.expand_path("../../picoruby/picoruby", PROJECT_ROOT)
  ].compact
  root = candidates.find { |candidate| File.file?(File.join(candidate, "Rakefile")) }
  return root if root

  abort "Set PICORUBY_ROOT to a PicoRuby checkout"
end

desc "Build PicoRuby with mruby-rack and run the smoke test"
task :test do
  root = picoruby_root
  env = {
    "MRUBY_CONFIG" => File.join(PROJECT_ROOT, "test", "picoruby_build_config.rb"),
    "MRUBY_RACK_ROOT" => PROJECT_ROOT
  }

  Dir.chdir(root) { sh env, "rake" }
  executable = File.join(root, "build", "mruby-rack-test", "bin", "mruby")
  sh executable, File.join(PROJECT_ROOT, "test", "smoke.rb")
  sh executable, File.join(PROJECT_ROOT, "test", "session_hash.rb")
  sh executable, File.join(PROJECT_ROOT, "test", "session.rb")
  sh executable, File.join(PROJECT_ROOT, "test", "cookie_simple.rb")
end

task default: :test
