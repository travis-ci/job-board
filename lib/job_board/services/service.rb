# frozen_string_literal: true
require_relative '../../l2met_log'

module JobBoard
  module Services
    class Service
      include L2metLog

      def self.run(*args)
        new(*args).run
      end
    end
  end
end
