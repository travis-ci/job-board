# frozen_string_literal: true
# DEPRECATED: to be removed after pre-v3.0.0 workers are gone

require_relative 'service'

module JobBoard
  module Services
    class AllocateJobs
      extend Service

      def initialize(jobs: [], capacity: 1, from: '', queue_name: '', site: '')
        @capacity = Integer(capacity)
        @from = from.to_s
        @jobs = Array(jobs)
        @job_queue = JobBoard::JobQueue.new(
          queue_name: queue_name.to_s,
          site: site.to_s
        )
      end

      attr_reader :jobs, :capacity, :from, :job_queue

      def run
        job_queue.register(worker: from, capacity: capacity)
        claimed = job_queue.check_claims(worker: from, job_ids: jobs)
        claimed += job_queue.claim(worker: from, capacity: capacity)

        {
          jobs: claimed,
          unavailable_jobs: jobs - claimed
        }
      end
    end
  end
end
