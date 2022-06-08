# frozen_string_literal: true

require_relative 'lib/faraday/retry/version'

Gem::Specification.new do |spec|
  spec.name = 'faraday-retry'
  spec.version = Faraday::Retry::VERSION
  spec.authors = ['Mattia Giuffrida']
  spec.email = ['giuffrida.mattia@gmail.com']

  spec.summary = 'Catches exceptions and retries each request a limited number of times'
  spec.description = <<~DESC
    Catches exceptions and retries each request a limited number of times.
  DESC
  spec.license = 'MIT'

  github_uri = "https://github.com/lostisland/#{spec.name}"

  spec.homepage = github_uri

  spec.metadata = {
    'bug_tracker_uri' => "#{github_uri}/issues",
    'changelog_uri' => "#{github_uri}/blob/v#{spec.version}/CHANGELOG.md",
    'documentation_uri' => "http://www.rubydoc.info/gems/#{spec.name}/#{spec.version}",
    'homepage_uri' => spec.homepage,
    'source_code_uri' => github_uri
  }

  spec.files = Dir['lib/**/*', 'README.md', 'LICENSE.md', 'CHANGELOG.md']

  spec.required_ruby_version = '>= 2.6', '< 4'

  spec.add_runtime_dependency 'faraday', '~> 2.0'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'simplecov', '~> 0.21.0'

  spec.add_development_dependency 'rubocop', '~> 1.21.0'
  spec.add_development_dependency 'rubocop-packaging', '~> 0.5.0'
  spec.add_development_dependency 'rubocop-performance', '~> 1.0'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.0'
end
