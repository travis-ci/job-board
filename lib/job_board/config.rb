# frozen_string_literal: true
require 'hashr'
require 'openssl'
require 'travis/config'

module JobBoard
  class Config < Travis::Config
    extend Hashr::Env

    def self.env
      ENV['ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    def env
      self.class.env
    end

    def jwt_public_key
      @jwt_public_key ||= begin
        OpenSSL::PKey::RSA.new(jwt_private_key).public_key
      rescue
        nil
      end
    end

    def paranoid_queue_names
      @paranoid_queue_names ||= paranoid_queues.split(',').map(&:strip)
    end

    define(
      auth: {
        tokens: ''
      },
      build: {
        fix_resolv_conf: false,
        fix_etc_hosts: false,
        hosts: {
          apt_cache: '',
          npm_cache: ''
        }
      },
      build_api_url: ENV.fetch('JOB_BOARD_BUILD_API_URL', ''),
      database: {
        url: '',
        sql_logging: false
      },
      images_name_format: '.*',
      job_max_duration: ENV.fetch('JOB_BOARD_JOB_MAX_DURATION', '10800'),
      job_state_com_url: ENV.fetch('JOB_BOARD_JOB_STATE_COM_URL', ''),
      job_state_org_url: ENV.fetch('JOB_BOARD_JOB_STATE_ORG_URL', ''),
      jwt_private_key: ENV.fetch('JOB_BOARD_JWT_PRIVATE_KEY', ''),
      log_level: 'info',
      log_parts_com_url: ENV.fetch('JOB_BOARD_LOG_PARTS_COM_URL', ''),
      log_parts_org_url: ENV.fetch('JOB_BOARD_LOG_PARTS_ORG_URL', ''),
      paranoid_queues: ENV.fetch('JOB_BOARD_PARANOID_QUEUES', 'docker,ec2'),
      redis_url: ENV.fetch(
        ENV.fetch('REDIS_PROVIDER', 'REDIS_URL'), 'redis://localhost:6379/0'
      ),
      worker_ttl: Integer(ENV.fetch('JOB_BOARD_WORKER_TTL', '120'))
    )

    default(access: [:key])
  end
end
