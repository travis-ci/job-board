require 'simplecov'

ENV['RACK_ENV'] = 'test'
ENV['DATABASE_SQL_LOGGING'] = nil

require 'job_board'
require 'rack/test'

module RackTestBits
  include Rack::Test::Methods

  def app
    JobBoard::App
  end
end

RSpec.configure do |c|
  c.include RackTestBits
end
