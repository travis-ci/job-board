# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class CreateOrUpdateJob < Service
      def initialize(params: {})
        @params = params
      end

      attr_reader :params

      def run
        job_id = params.fetch('id')
        queue = assign_queue(params)

        JobBoard::Models.db.transaction do
          job = JobBoard::Models::Job.first(job_id: job_id)
          if job.nil?
            create_new(job_id, queue, Sequel.pg_json(params))
          else
            job.set_all(queue: queue, data: Sequel.pg_json(params))
            job.save_changes
          end
        end
      end

      def update_existing(job, queue, data)
        job.queue = queue
        job.data = data
        job.save
      end

      def create_new(job_id, queue, data)
        JobBoard::Models.redis.multi do |conn|
          conn.sadd('queues', queue)
          conn.rpush(
            "queue:#{queue}",
            job_id
          )
        end

        JobBoard::Models::Job.create(
          job_id: job_id,
          queue: queue,
          data: data
        )
      end

      def assign_queue(job)
        JobBoard::Services::FetchQueue.run(job: job)
      end
    end
  end
end
