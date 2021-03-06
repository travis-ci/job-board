# frozen_string_literal: true

require 'time'

require_relative 'travis'

require 'connection_pool'
require 'redis-namespace'
require 'travis/logger'

module JobBoard
  autoload :App, 'job_board/app'
  autoload :Auth, 'job_board/auth'
  autoload :Config, 'job_board/config'
  autoload :ImageParams, 'job_board/image_params'
  autoload :ImageSearcher, 'job_board/image_searcher'
  autoload :ImageUpdater, 'job_board/image_updater'
  autoload :ImagesAPI, 'job_board/images_api'
  autoload :ImagesQuery, 'job_board/images_query'
  autoload :JobDeliveryAPI, 'job_board/job_delivery_api'
  autoload :JobQueriesTransformer, 'job_board/job_queries_transformer'
  autoload :JobQueue, 'job_board/job_queue'
  autoload :JobQueueReconciler, 'job_board/job_queue_reconciler'
  autoload :Models, 'job_board/models'
  autoload :Services, 'job_board/services'

  def config
    @config ||= JobBoard::Config.load
  end

  module_function :config

  def logger
    @logger ||= Travis::Logger.new(@logdev || $stdout, config)
  end

  module_function :logger

  attr_writer :logdev
  module_function :logdev=

  def version
    @version ||=
      `git rev-parse HEAD 2>/dev/null || echo ${SOURCE_VERSION:-fafafaf}`.strip
  end

  module_function :version

  def redis
    @redis ||= Redis::Namespace.new(
      :job_board, redis: Redis.new(url: config.redis_url)
    )
  end

  module_function :redis

  def redis_pool
    @redis_pool ||= ConnectionPool.new(config.redis_pool_options) do
      Redis::Namespace.new(
        :job_board, redis: Redis.new(url: config.redis_url)
      )
    end
  end

  module_function :redis_pool
end
