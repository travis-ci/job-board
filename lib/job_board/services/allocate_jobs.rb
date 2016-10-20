# frozen_string_literal: true
module JobBoard
  module Services
    class AllocateJobs
      def self.run(jobs: [], count: 1, from: '', queue: '')
        new(jobs: jobs, count: count, from: from, queue: queue).run
      end

      def initialize(jobs: [], count: 1, from: '', queue: '')
        @count = count
        @from = from
        @jobs = jobs
        @queue = queue
      end

      attr_reader :jobs, :count, :from, :queue

      def run
        redis.sadd('queues', queue)
        redis.sadd('workers', from)

        avail = []
        unavail = []
        jobs.each do |job_id|
          if redis.sismember("worker:#{from}", job_id)
            avail << job_id
            next
          end
          unavail << job_id
        end

        loop do
          break if avail.length + unavail.length >= count
          allocated = redis.lpop("queue:#{queue}")
          unless allocated.nil?
            redis.sadd("worker:#{from}", allocated)
            avail << allocated
          end
          break if allocated.nil?
        end

        {
          jobs: avail,
          unavailable_jobs: unavail
        }
      end

      private

      def redis
        JobBoard::Models.redis
      end
    end
  end
end
