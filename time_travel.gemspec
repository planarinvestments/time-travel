$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "time_travel/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "time_travel"
  s.version     = TimeTravel::VERSION
  s.authors     = [""]
  s.email       = [""]
  s.homepage    = "http://weinvest.net"
  s.summary     = "The Time travel gem adds history and correction tracking to models."
  s.description = "The time travel gem adds history and correction tracking to models."

  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.add_development_dependency "rails", "~> 5.2.1"
  s.add_development_dependency "rspec-rails", "~> 3.8"
  s.add_development_dependency "sqlite3", "1.3.11"
end
