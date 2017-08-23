# frozen_string_literal: true

require 'base64'
require 'openssl'

require 'hashr'
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
        jwt_private_key.public_key
      rescue => e
        warn e
        nil
      end
    end

    def jwt_private_key
      @jwt_private_key ||= begin
        value = super
        return OpenSSL::PKey::RSA.new(value) if value.start_with?('-----')
        OpenSSL::PKey::RSA.new(Base64.decode64(value))
      rescue => e
        warn e
        nil
      end
    end

    def paranoid_queue_names
      @paranoid_queue_names ||= paranoid_queues.split(',').map(&:strip)
    end

    def process_name
      ['job-board', env, ENV['DYNO'] || 'anon'].compact.join('.')
    end

    define(
      api_logging: ENV.fetch('JOB_BOARD_API_LOGGING', 'true') == 'true',
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
      build_api_com_url: ENV.fetch('JOB_BOARD_BUILD_API_COM_URL', ''),
      build_api_org_url: ENV.fetch('JOB_BOARD_BUILD_API_ORG_URL', ''),
      database: {
        url: '',
        sql_logging: false
      },
      images_name_format: '.*',
      job_max_duration: ENV.fetch('JOB_BOARD_JOB_MAX_DURATION', '10800'),
      job_state_com_url: ENV.fetch('JOB_BOARD_JOB_STATE_COM_URL', ''),
      job_state_org_url: ENV.fetch('JOB_BOARD_JOB_STATE_ORG_URL', ''),
      jwt_private_key: ENV.fetch('JOB_BOARD_JWT_PRIVATE_KEY', ''),
      log_level: ENV.fetch('JOB_BOARD_LOG_LEVEL', 'info'),
      log_parts_com_url: ENV.fetch('JOB_BOARD_LOG_PARTS_COM_URL', ''),
      log_parts_org_url: ENV.fetch('JOB_BOARD_LOG_PARTS_ORG_URL', ''),
      logger: { format_type: 'l2met', thread_id: true },
      paranoid_queues: ENV.fetch('JOB_BOARD_PARANOID_QUEUES', 'docker,ec2'),
      reconcile_purge_unknown_always: false,
      reconcile_purge_unknown_every: 42,
      reconcile_stats_with_ids: false,
      redis_url: ENV.fetch(
        ENV.fetch('REDIS_PROVIDER', 'REDIS_URL'), 'redis://localhost:6379/0'
      ),
      redis_pool_options: {
        size: 5,
        timeout: 3
      },
      sentry: { dsn: nil },
      processor_ttl: Integer(
        ENV.fetch(
          'JOB_BOARD_PROCESSOR_TTL',
          ENV.fetch('JOB_BOARD_WORKER_TTL', '10')
        )
      )
    )

    default(access: [:key])
  end
end
