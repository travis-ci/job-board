# frozen_string_literal: true

require_relative 'service'

module JobBoard
  module Services
    class AllocateJobs
      extend Service

      def initialize(jobs: [], count: 1, from: '', queue: '', site: '')
        @count = Integer(count)
        @from = from.to_s
        @jobs = Array(jobs)
        @job_queue = JobBoard::JobQueue.new(name: queue.to_s, site: site.to_s)
      end

      attr_reader :jobs, :count, :from, :job_queue

      def run
        job_queue.register(worker: from)
        claimed = job_queue.check_claims(worker: from, job_ids: jobs)

        loop do
          break if claimed.length >= count
          job_id = job_queue.claim(worker: from)
          break if job_id.nil?
          claimed << job_id
        end

        {
          jobs: claimed,
          unavailable_jobs: jobs - claimed
        }
      end
    end
  end
end
