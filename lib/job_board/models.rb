# frozen_string_literal: true
require 'logger'

require 'redis-namespace'
require 'sequel'
require 'sequel/model'

module JobBoard
  module Models
    autoload :Image, 'job_board/models/image'
    autoload :Job, 'job_board/models/job'

    class << self
      def db
        @db ||= Sequel.connect(
          JobBoard.config.database.url,
          max_connections: JobBoard.config.database.pool_size,
          logger: db_logger
        )
      end

      def db_logger
        @db_logger ||= (
          JobBoard.config.database.sql_logging ? Logger.new($stdout) : nil
        )
      end

      def initdb!
        return if @initdb
        Sequel.extension :core_extensions, :pg_hstore, :pg_json

        %w(images).each do |table|
          Sequel.qualify(:job_board, table.to_sym)
          table.to_sym.qualify(:job_board)
        end

        @initdb = db['select now()']
      end

      def redis
        @redis ||= Redis::Namespace.new(
          :job_board, redis: Redis.new(
            url: ENV.fetch(
              ENV['REDIS_PROVIDER'] || '', nil
            ) || ENV['REDIS_URL'] || 'redis://localhost:6379/0'
          )
        )
      end
    end

    initdb!
  end
end
