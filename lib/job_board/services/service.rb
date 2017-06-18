# frozen_string_literal: true

module JobBoard
  module Services
    module Service
      def run(*args)
        new(*args).run
      end
    end
  end
end
