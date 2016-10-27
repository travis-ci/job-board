# frozen_string_literal: true

require_relative 'service'

module JobBoard
  module Services
    class AllocateJobs
      extend Service

      def initialize(jobs: [], count: 1, from: '', queue_name: '', site: '')
        @count = Integer(count)
        @from = from.to_s
        @jobs = Array(jobs)
        @job_queue = JobBoard::JobQueue.new(
          queue_name: queue_name.to_s,
          site: site.to_s
        )
      end

      attr_reader :jobs, :count, :from, :job_queue

      def run
        job_queue.register(worker: from)
        claimed = job_queue.check_claims(worker: from, job_ids: jobs)
        claimed += job_queue.claim(worker: from, max: count - claimed.length)

        {
          jobs: claimed,
          unavailable_jobs: jobs - claimed
        }
      end
    end
  end
end
