# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class DeleteJob < Service
      def initialize(job_id: job_id)
        @job_id = job_id
      end

      attr_reader :job_id

      def run
      end
    end
  end
end
