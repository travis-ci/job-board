require 'travis/config'
require 'hashr'

module JobBoard
  class Config < Travis::Config
    extend Hashr::EnvDefaults

    def self.env
      ENV['ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    def env
      self.class.env
    end

    define auth: { tokens: '' },
           database: { url: '', sql_logging: false }

    default(access: [:key])
  end
end
