# frozen_string_literal: true

require_relative 'service'

module JobBoard
  module Services
    class AllocateJob
      extend Service

      def initialize(from: '', queue_name: '', site: '')
        @from = from.to_s
        @job_queue = JobBoard::JobQueue.new(
          queue_name: queue_name.to_s.strip,
          site: site.to_s.strip
        )
      end

      attr_reader :from, :job_queue

      def run
        job_queue.register(processor: from)
        job_queue.claim(processor: from)
      end
    end
  end
end
