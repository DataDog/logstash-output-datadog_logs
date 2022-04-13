# Load version.rb containing the DatadogLogStashPlugin::VERSION
# for current Gem version.
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "logstash/outputs/version.rb"

Gem::Specification.new do |s|
  s.name          = 'logstash-output-datadog_logs'
  s.version       = DatadogLogStashPlugin::VERSION
  s.licenses      = ['Apache-2.0']
  s.summary       = 'DatadogLogs lets you send logs to Datadog based on LogStash events.'
  s.homepage      = 'https://www.datadoghq.com/'
  s.authors       = ['Datadog', 'Alexandre Jacquemot']
  s.email         = 'support@datadoghq.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*', 'spec/**/*', 'vendor/**/*', '*.gemspec', '*.md', 'CONTRIBUTORS', 'Gemfile', 'LICENSE', 'NOTICE.TXT']
  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = {"logstash_plugin" => "true", "logstash_group" => "output"}

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency 'manticore', '>= 0.5.2', '< 1.0.0'
  s.add_runtime_dependency 'logstash-codec-json'

  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'webmock'
end
