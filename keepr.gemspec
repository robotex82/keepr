# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'keepr/version'

Gem::Specification.new do |spec|
  spec.name          = 'keepr'
  spec.version       = Keepr::VERSION
  spec.authors       = 'Georg Ledermann'
  spec.email         = 'georg@ledermann.dev'
  spec.description   = 'Double entry bookkeeping with Rails'
  spec.summary       = 'Some basic ActiveRecord models to build a double entry bookkeeping application'
  spec.homepage      = 'https://github.com/ledermann/keepr'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 6.1'
  spec.add_dependency 'ancestry', '>= 3.1.0'
  spec.add_dependency 'concurrent-ruby', '>= 1.3.1'
  spec.add_dependency 'datev', '>= 0.5.0'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
