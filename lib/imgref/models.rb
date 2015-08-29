require 'sequel'
require 'sequel/model'

module IMGRef
  module Models
    autoload :Image, 'imgref/models/image'
    autoload :Override, 'imgref/models/override'

    class << self
      def db
        @db ||= Sequel.connect(
          IMGRef.config.database.url,
          max_connections: IMGRef.config.database.pool_size,
          logger: db_logger
        )
      end

      def db_logger
        @db_logger ||= (
          IMGRef.config.database.sql_logging ? Logger.new($stderr) : nil
        )
      end

      def initdb!
        return if @initdb
        Sequel.extension :core_extensions, :pg_hstore

        %w(images overrides).each do |table|
          :"imgref__#{table}"
          Sequel.qualify(:imgref, table.to_sym)
          table.to_sym.qualify(:imgref)
        end

        @initdb = db['select now()']
      end
    end

    initdb!
  end
end
