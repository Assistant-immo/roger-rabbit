require File.expand_path("../lib/roger_rabbit/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "roger_rabbit"
  s.version = RogerRabbit::VERSION.dup
  s.license = "MIT"
  s.date = "2019-02-12"
  s.summary = %q{Wrapper around bunny for simple, direct,
    dry-code RabbitMQ messaging.}

  s.required_ruby_version = Gem::Requirement.new(">= 2.2")

  s.authors = [
    "Frederic Grais",
    "Vladan Djeric",
    "Nicolas Marlier"
  ]
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- spec/*`.split("\n")

  s.add_dependency 'bunny', '~> 2.13.0', '>= 2.13.0'
  s.add_development_dependency 'rspec', '~> 3.7'

  s.require_paths = ["lib"]
end
