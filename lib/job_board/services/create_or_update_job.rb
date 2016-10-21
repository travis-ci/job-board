# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class CreateOrUpdateJob < Service
      def initialize(job: {}, site: '')
        @job = job
        @site = site.to_s
      end

      attr_reader :job, :site

      def run
        return nil if site.empty? || job.nil? || job.empty?

        job_id = job.fetch('id')

        JobBoard::Models.db.transaction do
          db_job = JobBoard::Models::Job.first(job_id: job_id.to_s)
          if db_job.nil?
            return create_new(
              job_id, site, queue,
              Sequel::Postgres::JSONHash.new(job.to_hash)
            ).to_hash
          else
            db_job.set_all(
              queue: queue, site: site,
              data: Sequel::Postgres::JSONHash.new(job.to_hash)
            )
            db_job.save_changes
            db_job.to_hash
          end
        end
      end

      def queue
        return @queue if @queue
        @queue = job.fetch('data').fetch('queue', nil)
        if @queue.nil?
          @queue = assign_queue
          log level: :warn, msg: 'nil queue from scheduler', new: @queue
        end

        @queue = @queue.sub(/^builds\./, '')
      end

      def create_new(job_id, site, queue, data)
        JobBoard::Models.redis.multi do |conn|
          conn.sadd("queues:#{site}", queue)
          conn.rpush(
            "queue:#{site}:#{queue}",
            job_id
          )
        end

        JobBoard::Models::Job.create(
          data: data,
          job_id: job_id,
          queue: queue,
          site: site
        )
      end

      def assign_queue
        JobBoard::Services::FetchQueue.run(job: job)
      end
    end
  end
end
