# frozen_string_literal: true
require_relative '../../l2met_log'

module JobBoard
  module Services
    module Service
      def self.extended(class_type)
        class_type.send(:include, L2metLog)
      end

      def run(*args)
        new(*args).run
      end
    end
  end
end
