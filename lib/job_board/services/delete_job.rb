# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class DeleteJob < Service
      def initialize(job_id: '')
        @job_id = job_id
      end

      attr_reader :job_id

      def run
        JobBoard::Models.db.transaction do
          job = JobBoard::Models::Job.first(job_id: job_id)

          redis.lrem("queue:#{job.queue}", 1, job_id)
          workers = redis.smembers('workers')
          redis.multi do |_conn|
            workers.each do |worker|
              redis.srem("worker:#{worker}", job_id)
            end
          end

          job.delete
        end
      end

      def redis
        JobBoard::Models.redis
      end
    end
  end
end
