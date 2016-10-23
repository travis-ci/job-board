# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class CreateOrUpdateJob
      extend Service

      def initialize(job: {}, site: '')
        @job = job
        @site = site.to_s
      end

      attr_reader :job, :site

      def run
        return nil if site.empty? || job.nil? || job.empty?

        job_id = job.fetch('id')

        db_job = JobBoard::Models::Job.first(job_id: job_id.to_s)
        if db_job.nil?
          return create_new(
            data: Sequel::Postgres::JSONHash.new(job.to_hash),
            job_id: job_id,
            queue: queue,
            site: site
          ).to_hash
        else
          transaction do
            db_job.set_all(
              data: Sequel::Postgres::JSONHash.new(job.to_hash),
              queue: queue,
              site: site
            )
            db_job.save_changes
            db_job.to_hash
          end
        end
      end

      private

      def queue
        return @queue if @queue
        @queue = job.fetch('data').fetch('queue', nil)
        if @queue.nil?
          @queue = assign_queue
          log level: :warn, msg: 'nil queue from scheduler', new: @queue
        end

        @queue = @queue.sub(/^builds\./, '')
      end

      def create_new(job_id: '', site: '', queue: '', data: {})
        transaction do
          JobBoard::JobQueue.new(
            name: queue,
            site: site
          ).add(
            job_id: job_id
          )

          JobBoard::Models::Job.create(
            data: data,
            job_id: job_id,
            queue: queue,
            site: site
          )
        end
      end

      def assign_queue
        JobBoard::Services::FetchQueue.run(job: job)
      end

      def transaction(&block)
        JobBoard::Models.db.transaction(&block)
      end
    end
  end
end
