Gem::Specification.new do |s|
  s.name = "tickwork"
  s.version = "0.9.0"

  s.authors = ["John Hinnegan"]
  s.license = 'MIT'
  s.description = "A fork of clockwork. Under development."
  s.email = ["tickwork@johnhinnegan.com"]
  s.extra_rdoc_files = [
    "README.md"
  ]
  s.homepage = "http://github.com/softwaregravy/clockwork"
  s.summary = "A scheduling library"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency(%q<tzinfo>)
  s.add_dependency(%q<activesupport>)

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
  s.add_development_dependency "daemons"
  s.add_development_dependency "minitest", "~> 5.8"
  s.add_development_dependency "mocha"
end
