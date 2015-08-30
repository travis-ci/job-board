module JobBoard
  autoload :App, 'job_board/app'
  autoload :Config, 'job_board/config'
  autoload :Models, 'job_board/models'
  autoload :Services, 'job_board/services'

  def config
    @config ||= Config.load
  end

  module_function :config
end
