require 'sequel'
require 'sequel/model'

module CareerCenter
  module Models
    autoload :Image, 'career_center/models/image'
    autoload :Override, 'career_center/models/override'

    class << self
      def db
        @db ||= Sequel.connect(
          CareerCenter.config.database.url,
          max_connections: CareerCenter.config.database.pool_size,
          logger: db_logger
        )
      end

      def db_logger
        @db_logger ||= (
          CareerCenter.config.database.sql_logging ? Logger.new($stderr) : nil
        )
      end

      def initdb!
        return if @initdb
        Sequel.extension :core_extensions, :pg_hstore

        %w(images overrides).each do |table|
          :"career_center__#{table}"
          Sequel.qualify(:career_center, table.to_sym)
          table.to_sym.qualify(:career_center)
        end

        @initdb = db['select now()']
      end
    end

    initdb!
  end
end
