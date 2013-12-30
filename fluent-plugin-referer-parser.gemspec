# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = 'fluent-plugin-referer-parser'
  gem.version       = '0.0.2'
  gem.authors       = ['TAGOMORI Satoshi', 'HARUYAMA Seigo']
  gem.email         = ['tagomoris@gmail.com', 'haruyama@unixuser.org']
  gem.description   = %q{parsing by referer-parser. See: https://github.com/snowplow/referer-parser}
  gem.summary       = %q{Fluentd plugin to parse UserAgent strings}
  gem.homepage      = 'https://github.com/haruyama/fluent-plugin-referer-parser'
  gem.license       = 'APLv2'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_development_dependency 'rake'
  gem.add_runtime_dependency 'fluentd'
  gem.add_runtime_dependency 'referer-parser', '>= 0.2.0'
end
