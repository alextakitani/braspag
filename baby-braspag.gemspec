# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "baby-braspag/version"

Gem::Specification.new do |s|
  s.name        = "baby-braspag"
  s.version     = Braspag::VERSION
  s.authors     = ["baby dev"]
  s.email       = %w["dev-team@baby.com.br"]
  s.homepage    = "https://github.com/Baby-com-br/braspag"
  s.summary     = "baby braspag gem to use Braspag gateway"
  s.description = "baby braspag gem to use Braspag gateway"

  s.rubyforge_project = "baby-braspag"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'httpi', '~> 2.3.0'
  s.add_dependency 'json', '>= 1.6.1'
  s.add_dependency 'nokogiri', '~> 1.6.1'
  s.add_dependency 'savon', '~> 2.11.0'

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", '~> 2.12.0'
  s.add_development_dependency "fakeweb"
  s.add_development_dependency "shoulda-matchers"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "guard-bundler"
  s.add_development_dependency "pry"
  s.add_development_dependency "pry-byebug"
  s.add_development_dependency "awesome_print"
end
