require_relative 'job_board'

module Travis
  def config
    JobBoard.config
  end

  module_function :config

  def logger
    JobBoard.logger
  end

  module_function :logger
end
