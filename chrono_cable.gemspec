require_relative "lib/chrono_cable/version"

Gem::Specification.new do |spec|
  spec.name        = "chrono_cable"
  spec.version     = ChronoCable::VERSION
  spec.authors     = [ "Nick Pezza" ]
  spec.email       = [ "pezza@hey.com" ]
  spec.homepage    = "https://github.com/npezza93/chrono_cable"
  spec.summary     = "Ordered, recoverable Action Cable streams backed by Solid Cable."
  spec.description = "Adds per-stream sequence numbers and history replay to Action Cable broadcasts stored by Solid Cable."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", "> 8.1"
  spec.add_dependency "solid_cable", "> 4.0"
end
