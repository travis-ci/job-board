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
          logger: db_logger,
          after_connect: ->(c) { after_connect(c) },
          preconnect: preconnect?
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
        @initdb = db['select now()'].first
      end

      private def after_connect(conn)
        execute_compat(
          conn, "SET application_name = '#{JobBoard.config.process_name}'"
        )
        execute_compat(
          conn, "SET statement_timeout = #{statement_timeout_ms}"
        )
      end

      private def statement_timeout_ms
        @statement_timeout_ms ||= if ENV['DYNO'].to_s.start_with?('web.')
                                    30 * 1_000
                                  else
                                    30 * 60 * 1_000
                                  end
      end

      private def execute_compat(conn, statement)
        if conn.respond_to?(:exec)
          conn.exec(statement)
        elsif conn.respond_to?(:execute)
          conn.execute(statement)
        elsif conn.respond_to?(:create_statement)
          st = conn.create_statement
          st.execute(statement)
          st.close
        end
      end

      private def preconnect?
        %w[true 1].include?(ENV['PGBOUNCER_ENABLED'].to_s.downcase)
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
