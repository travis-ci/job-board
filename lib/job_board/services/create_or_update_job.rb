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
        puts '-----Create 1 Start-----'
        puts 'create-jobs-add'
        puts db_job
        puts '-----Create 1 End-----'
        if db_job.nil?
          JobBoard.logger.info(
            'creating new job record', job: job_id, queue: queue, site: site
          )
          return create_new(
            data: Sequel::Postgres::JSONHash.new(job.to_hash),
            job_id: job_id,
            queue_name: queue,
            site: site
          ).to_hash
        else
          JobBoard.logger.info(
            'updating existing job record', job: job_id, queue: queue
          )
          db_job.set(
            data: Sequel::Postgres::JSONHash.new(job.to_hash),
            queue: queue,
            site: site
          )
          db_job.save_changes
          puts '-----Create 2 Start-----'
          puts 'create-jobs-add'
          puts db_job.to_hash
          puts '-----Create 2 End-----'
          db_job.to_hash
        end
      end

      private def queue
        return @queue if @queue

        @queue = job.fetch('data', {}).fetch('queue', nil)
        if @queue.nil?
          @queue = assign_queue
          JobBoard.logger.warn(
            'nil queue from scheduler', new: @queue, job: job.fetch('id')
          )
        end

        @queue = @queue.sub(/^builds\./, '')
      end

      private def create_new(job_id: '', site: '', queue_name: '', data: {})
        JobBoard::JobQueue.new(
          queue_name: queue_name,
          site: site
        ).add(
          job_id: job_id
        )

        JobBoard::Models::Job.create(
          data: data,
          job_id: job_id,
          queue: queue_name,
          site: site
        )
      end

      private def assign_queue
        JobBoard::Services::FetchQueue.run(job: job)
      end
    end
  end
end
