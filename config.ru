#!/usr/bin/env rackup
# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'raven'
require 'job_board'

$stdout.sync = true if ENV.key?('DYNO')
STDOUT.sync = true if ENV.key?('DYNO')

unless %w[development test].include?(ENV['RACK_ENV'] || 'bogus')
  require 'rack/ssl'
  use Rack::SSL
end

use Raven::Rack if JobBoard.config.sentry.dsn

run JobBoard::App
