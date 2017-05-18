# frozen_string_literal: true

require_relative 'service'

module JobBoard
  module Services
    class FetchQueue
      extend Service

      def initialize(job: {})
        @job = job
      end

      attr_reader :job

      def run
        # TODO: implement proper queue selection via databass
        'gce'
      end
    end
  end
end
