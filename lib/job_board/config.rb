# frozen_string_literal: true
require 'travis/config'
require 'hashr'

module JobBoard
  class Config < Travis::Config
    extend Hashr::Env

    def self.env
      ENV['ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    def env
      self.class.env
    end

    define(
      auth: {
        tokens: ''
      },
      build: {
        paranoid: true,
        fix_resolv_conf: false,
        fix_etc_hosts: false,
        hosts: {
          apt_cache: '',
          npm_cache: ''
        }
      },
      build_api_url: ENV.fetch('JOB_BOARD_BUILD_API_URL', ''),
      cache_options: {
        type: '',
        fetch_timeout: 300,
        push_timeout: 300,
        s3: {
          scheme: '',
          region: '',
          bucket: '',
          access_key_id: '',
          secret_access_key: ''
        }
      },
      database: {
        url: '',
        sql_logging: false
      },
      images_name_format: '.*',
      job_delivery_api: {
        enabled: ENV.fetch(
          'JOB_BOARD_JOB_DELIVERY_API_ENABLED', '0'
        ) == '1'
      },
      job_state_url: ENV.fetch('JOB_BOARD_JOB_STATE_URL', ''),
      log_level: 'info',
      log_parts_url: ENV.fetch('JOB_BOARD_LOG_PARTS_URL', '')
    )

    default(access: [:key])
  end
end
