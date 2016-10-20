# frozen_string_literal: true

require 'simplecov'
require 'codeclimate-test-reporter'

if ENV['COVERAGE'] && ENV['INTEGRATION_SPECS'] == '1'
  CodeClimate::TestReporter.start
end

ENV['RACK_ENV'] = 'test'
ENV['LOG_LEVEL'] = 'fatal'
ENV['DATABASE_URL'] = 'mock://' unless ENV['INTEGRATION_SPECS'] == '1'
ENV['DATABASE_SQL_LOGGING'] = nil

require 'job_board'
require 'rack/test'
require 'factory_girl'

module RackTestBits
  include Rack::Test::Methods

  def app
    Rack::URLMap.new('/jobs' => JobBoard::JobDeliveryAPI,
                     '/images' => JobBoard::ImagesAPI)
  end
end

FactoryGirl.define do
  factory :image, class: JobBoard::Models::Image do
    to_create(&:save)
  end
end

integration_enabled = ENV['INTEGRATION_SPECS'] == '1'

RSpec.configure do |c|
  c.include RackTestBits
  c.include FactoryGirl::Syntax::Methods
  c.filter_run_excluding(integration: true) unless integration_enabled
end
