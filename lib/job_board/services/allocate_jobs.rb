# frozen_string_literal: true

require_relative 'service'

module JobBoard
  module Services
    class AllocateJobs < Service
      def initialize(jobs: [], count: 1, from: '', queue: '', site: '')
        @count = count
        @from = from
        @jobs = jobs || []
        @queue = queue
        @site = site
      end

      attr_reader :jobs, :count, :from, :queue, :site

      def run
        redis.sadd("queues:#{site}", queue)
        redis.sadd("workers:#{site}", from)

        avail = []
        unavail = []
        jobs.each do |job_id|
          if redis.sismember("worker:#{site}:#{from}", job_id)
            avail << job_id
            next
          end
          unavail << job_id
        end

        loop do
          break if avail.length + unavail.length >= count
          allocated = redis.lpop("queue:#{site}:#{queue}")
          unless allocated.nil?
            redis.sadd("worker:#{site}:#{from}", allocated)
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
