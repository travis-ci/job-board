# frozen_string_literal: true

module JobBoard
  module Services
    class Service
      def self.run(*args)
        new(*args).run
      end
    end
  end
end
