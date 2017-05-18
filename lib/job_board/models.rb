# frozen_string_literal: true

require 'logger'

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
        @db_logger ||= begin
          JobBoard.config.database.sql_logging ? Logger.new($stdout) : nil
        end
      end

      def initdb!
        return if @initdb
        Sequel.extension(*global_extensions)

        %w[images jobs].each do |table|
          Sequel.qualify(:job_board, table.to_sym)
          table.to_sym.qualify(:job_board)
        end

        db.extension(*connection_extensions)
        @initdb = db['select now()']
      end

      private def global_extensions
        %i[core_extensions pg_hstore pg_json]
      end

      private def connection_extensions
        return [] if JobBoard.config.database.url.start_with?('mock')
        %i[pg_hstore pg_json]
      end
    end

    initdb!
  end
end
