# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class DeleteJob
      extend Service

      def initialize(job_id: '', site: '')
        @job_id = job_id
        @site = site
      end

      attr_reader :job_id, :site

      def run
        JobBoard::Models.db.transaction do
          job = JobBoard::Models::Job.first(job_id: job_id, site: site)
          raise Sequel::Rollback if job.nil?

          queue = JobBoard::JobQueue.new(queue_name: job.queue, site: site)
          queue.remove(job_id: job_id)

          job.delete
        end
      end
    end
  end
end
