lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'samvera/nesting_indexer/version'

Gem::Specification.new do |spec|
  spec.name          = "samvera-nesting_indexer"
  spec.version       = Samvera::NestingIndexer::VERSION
  spec.authors       = ["Jeremy Friesen"]
  spec.email         = ["jeremy.n.friesen@gmail.com"]

  spec.summary       = %q{Samvera nested collections indexing}
  spec.description   = %q{Samvera nested collections indexing}
  spec.homepage      = "https://github.com/samvera-labs/samvera-nesting_indexer"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '~>2.0'

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "codeclimate-test-reporter"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "guard-rubocop"
  spec.add_development_dependency "json"
  spec.add_development_dependency "listen", '~> 3.0.8'
  spec.add_development_dependency "railties"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec-its"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "terminal-notifier-guard"
  spec.add_development_dependency "terminal-notifier"
  spec.add_dependency "dry-equalizer"
end
