# frozen_string_literal: true

require 'simplecov'

def integration?
  ENV['INTEGRATION_SPECS'] == '1'
end

ENV['RACK_ENV'] = 'test'
ENV['LOG_LEVEL'] = 'fatal'
ENV['DATABASE_URL'] = 'mock://' unless integration?
ENV['DATABASE_SQL_LOGGING'] = nil
ENV['AUTH_TOKENS'] = 'test'
ENV['JOB_BOARD_JWT_PRIVATE_KEY'] = File.read(
  File.expand_path('../test_rsa', __FILE__)
)

require 'job_board'
require 'rack/test'
require 'factory_girl'
require 'fakeredis/rspec' unless integration?

module RackTestBits
  include Rack::Test::Methods

  def app
    JobBoard::App
  end
end

FactoryGirl.define do
  factory :image, class: JobBoard::Models::Image do
    to_create(&:save)
  end
end

RSpec.configure do |c|
  c.include RackTestBits
  c.include FactoryGirl::Syntax::Methods
  c.filter_run_excluding(integration: true) unless integration?
  c.before(:suite) do
    JobBoard.redis_pool.with do |redis|
      redis.srem('sites', 'test')
      redis.del('queues:test')

      redis.scan_each(match: 'queue:test:*') do |key|
        redis.del(key)
      end

      redis.scan_each(match: 'processor:test:*') do |key|
        redis.del(key)
      end
    end
  end
end
