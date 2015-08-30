require 'sequel'
require 'sequel/model'

module JobBoard
  module Models
    autoload :Image, 'job_board/models/image'
    autoload :JobRouteOverride, 'job_board/models/job_route_override'

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
          JobBoard.config.database.sql_logging ? Logger.new($stderr) : nil
        )
      end

      def initdb!
        return if @initdb
        Sequel.extension :core_extensions, :pg_hstore

        %w(images job_route_overrides).each do |table|
          :"job_board__#{table}"
          Sequel.qualify(:job_board, table.to_sym)
          table.to_sym.qualify(:job_board)
        end

        @initdb = db['select now()']
      end
    end

    initdb!
  end
end
