# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class DeleteJob < Service
      def initialize(job_id: '', site: '')
        @job_id = job_id
        @site = site
      end

      attr_reader :job_id, :site

      def run
        JobBoard::Models.db.transaction do
          job = JobBoard::Models::Job.first(job_id: job_id, site: site)
          raise Sequel::Rollback if job.nil?

          redis.lrem("queue:#{site}:#{job.queue}", 1, job_id)
          workers = redis.smembers("workers:#{site}")
          redis.multi do |_conn|
            workers.each do |worker|
              redis.srem("worker:#{site}:#{worker}", job_id)
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
