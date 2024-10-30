#!/usr/bin/env rackup
# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'job_board'

$stdout.sync = true if ENV.key?('DYNO')
STDOUT.sync = true if ENV.key?('DYNO')

if !%w[development test].include?(ENV['RACK_ENV'] || 'bogus') && !ENV['DOCKER']
  require 'rack/ssl'
  use Rack::SSL
end

run JobBoard::App
