# frozen_string_literal: true
require 'job_board'
require 'rack/test'

module RackTestBits
  include Rack::Test::Methods

  def app
    JobBoard::App
  end
end
