
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rack/params/version"

Gem::Specification.new do |spec|
  spec.name          = "rack-params"
  spec.version       = Rack::Params::VERSION
  spec.authors       = ["Jon Raphaelson"]
  spec.email         = ["jon@accidental.cc"]

  spec.summary       = %q{Rack parameter validation and type coercion.}
  spec.homepage      = "https://github.com/lygaret/rack-params"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", "~> 2.0"
end
