# frozen_string_literal: true

require 'job_board'
require_relative 'service'

module JobBoard
  module Services
    class SearchJobs
      extend Service

      def initialize(site: '', queue_name: nil, worker: nil)
        @site = site
        @queue_name = queue_name.to_s.strip
        @worker = worker.to_s.strip
      end

      attr_reader :site, :queue_name, :worker

      def run
        results = { jobs: [], :@site => site }

        if queue_name.empty?
          results[:jobs] = JobBoard::JobQueue.for_site(
            site: site
          )
        elsif worker.empty?
          results[:@queue] = queue_name
          results[:jobs] = JobBoard::JobQueue.for_queue(
            site: site, queue_name: queue_name
          )
        else
          results[:@queue] = queue_name
          results[:@worker] = worker
          results[:jobs] = JobBoard::JobQueue.for_worker(
            site: site, queue_name: queue_name, worker: worker
          )
        end

        results
      rescue JobBoard::JobQueue::Invalid => e
        { error: e, :@site => site }
      end
    end
  end
end
