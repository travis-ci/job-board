# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class CreateJob < Service
      def initialize(params: {})
        @params = params
      end

      attr_reader :params

      def run
        job_id = params.fetch('id')
        queue = assign_queue(params)

        JobBoard::Models.db.transaction do
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
            data: Sequel.pg_json(params)
          )
        end
      end

      def assign_queue(job)
        JobBoard::Services::FetchQueue.run(job: job)
      end
    end
  end
end
