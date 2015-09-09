require_relative 'travis'
require 'travis/support/logger'
require 'travis/support/logging'

module JobBoard
  autoload :App, 'job_board/app'
  autoload :Config, 'job_board/config'
  autoload :Models, 'job_board/models'
  autoload :Services, 'job_board/services'

  def config
    @config ||= Config.load
  end

  module_function :config

  def logger
    @logger ||= Travis::Logger.configure(Travis::Logger.new($stdout))
  end

  module_function :logger
end