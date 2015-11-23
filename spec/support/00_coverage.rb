require 'simplecov'
require 'codeclimate-test-reporter'

if ENV['COVERAGE'] && ENV['INTEGRATION_SPECS'] == '1'
  CodeClimate::TestReporter.start
end
