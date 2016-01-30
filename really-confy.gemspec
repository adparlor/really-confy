Gem::Specification.new do |s|
  s.name    = "really-confy"
  s.version = "0.2.2"
  s.date    = "2015-10-31"
  s.summary = "Simple YAML configuration loader"
  s.authors = ["Matt Zukowski", "Edward Tam"]
  s.email   = "mzukowski@adknowledge.com"
  s.files   = ["lib/really_confy.rb", ]
  s.license = "MIT"

  s.add_runtime_dependency 'rainbow', '~> 2.0'
  s.add_runtime_dependency 'hashie', '~> 3.4'
end
