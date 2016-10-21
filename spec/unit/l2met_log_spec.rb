# frozen_string_literal: true
require 'l2met_log'

class LoggingThing
  include L2metLog
end

describe L2metLog do
  let(:thing) { LoggingThing.new }

  before do
    ENV['APP_NAME'] ||= 'thing'
    L2metLog.default_log_level = :debug
  end

  after do
    L2metLog.default_log_level = :fatal
  end

  it 'can log things' do
    thing.log measure: 'something.already' do
      'is this awesome'.upcase + '?!?!'
    end
  end
end
