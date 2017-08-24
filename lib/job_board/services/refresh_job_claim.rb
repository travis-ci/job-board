# frozen_string_literal: true

require_relative 'service'

module JobBoard
  module Services
    class RefreshJobClaim
      extend Service

      def initialize(job_id: '', from: '', queue_name: '', site: '')
        @from = from.to_s
        @job_id = job_id.to_s.strip
        @job_queue = JobBoard::JobQueue.new(
          queue_name: queue_name.to_s.strip,
          site: site.to_s.strip
        )
      end

      attr_reader :job_id, :from, :job_queue

      def run
        job_queue.register(processor: from)
        job_queue.claimed?(processor: from, job_id: job_id)
      end
    end
  end
end
