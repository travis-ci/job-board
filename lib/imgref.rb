module IMGRef
  autoload :App, 'imgref/app'
  autoload :Config, 'imgref/config'
  autoload :Models, 'imgref/models'
  autoload :Services, 'imgref/services'

  def config
    @config ||= Config.load
  end

  module_function :config
end
