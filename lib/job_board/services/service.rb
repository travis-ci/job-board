# frozen_string_literal: true

require 'l2met-log'

module JobBoard
  module Services
    module Service
      def self.extended(class_type)
        class_type.send(:include, L2met::Log)
      end

      def run(*args)
        new(*args).run
      end
    end
  end
end
