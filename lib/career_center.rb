module CareerCenter
  autoload :App, 'career_center/app'
  autoload :Config, 'career_center/config'
  autoload :Models, 'career_center/models'
  autoload :Services, 'career_center/services'

  def config
    @config ||= Config.load
  end

  module_function :config
end
