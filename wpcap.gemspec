# -*- encoding: utf-8 -*-
require File.expand_path('../lib/wpcap/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Russell Osborne"]
  gem.email         = ["russell@burningpony.com"]
  gem.description   = "A Tool to Setup, Maintain, and Deploy Capistrano Driven Wordpress Sites"
  gem.summary       = "A Tool to Setup, Maintain, and Deploy Capistrano Driven Wordpress Sites on any cloud server or linux macine"
  gem.homepage      = "https://github.com/rposborne/wpcap"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "wpcap"
  gem.require_paths = ["lib"]
  gem.version       = Wpcap::VERSION
  gem.add_dependency('capistrano')
  gem.add_dependency('railsless-deploy')
  gem.add_dependency('thor')
  gem.add_development_dependency('guard')
  gem.add_development_dependency('guard-rspec')
  gem.add_development_dependency('webmock')
  gem.add_development_dependency('rb-fsevent')
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('fakefs')
end
