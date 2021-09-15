$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "time_travel/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "time-travel"
  s.version     = TimeTravel::VERSION
  s.authors     = [""]
  s.email       = [""]
  s.homepage    = "https://github.com/planarinvestments/time-travel"
  s.summary     = "The Time travel gem adds in-table version control to models."
  s.description = "The time travel gem adds in-table version control to models."

  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib,sql}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.add_development_dependency "rails", "~> 5.2"
  s.add_development_dependency "rspec-rails", "~> 3.8"
  s.add_development_dependency "pg"
  s.add_development_dependency "timecop"
end
