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
        redis.multi do |conn|
          conn.sadd("queues:#{site}", queue)
          conn.sadd("workers:#{site}", from)
        end

        avail = []
        unavail = []
        jobs.each do |job_id|
          if redis.sismember(worker_index_set_key, job_id)
            avail << job_id
            next
          end
          unavail << job_id
        end

        loop do
          break if avail.length + unavail.length >= count
          allocated = redis.rpoplpush(
            queue_key,
            worker_queue_list_key
          )
          unless allocated.nil?
            redis.multi do |conn|
              conn.sadd(worker_index_set_key, allocated)
              conn.expire(worker_index_set_key, ttl)
              conn.expire(worker_queue_list_key, ttl)
            end
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

      def worker_index_set_key
        "#{worker_queue_list_key}:idx"
      end

      def worker_queue_list_key
        "worker:#{site}:#{from}"
      end

      def queue_key
        "queue:#{site}:#{queue}"
      end

      def ttl
        JobBoard.config.worker_ttl
      end

      def redis
        JobBoard::Models.redis
      end
    end
  end
end
