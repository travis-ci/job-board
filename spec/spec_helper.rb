require 'simplecov'

ENV['RACK_ENV'] = 'test'
ENV['DATABASE_SQL_LOGGING'] = nil

require 'career_center'
require 'rack/test'

module RackTestBits
  include Rack::Test::Methods

  def app
    CareerCenter::App
  end
end

RSpec.configure do |c|
  c.include RackTestBits
end
