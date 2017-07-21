# frozen_string_literal: true

require 'job_board'
require_relative 'service'

module JobBoard
  module Services
    class SearchJobs
      extend Service

      def initialize(site: '', queue_name: nil, worker: nil)
        @site = site
        @queue_name = queue_name
        @worker = worker
      end

      attr_reader :site, :queue_name, :worker

      def run
        results = { jobs: nil, :@site => site }

        if queue_name.to_s.strip.empty?
          results[:jobs] = JobBoard::JobQueue.for_site(
            site: site
          )
        else
          results[:@queue] = queue_name
          results[:jobs] = JobBoard::JobQueue.for_queue(
            site: site, queue_name: queue_name
          )
        end

        if worker.to_s != ''
          results[:@worker] = worker
          results[:jobs].select! do |_, claim|
            !claim[:claimed_by].nil? &&
              File.fnmatch(worker, claim[:claimed_by])
          end
        end

        results
      rescue JobBoard::JobQueue::Invalid => e
        { error: e, :@site => site }
      end
    end
  end
end
