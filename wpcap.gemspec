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
end
