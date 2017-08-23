# frozen_string_literal: true

require 'job_board'
require_relative 'service'

module JobBoard
  module Services
    class SearchJobs
      extend Service

      def initialize(site: '', queue_name: nil, processor: nil)
        @site = site
        @queue_name = queue_name.to_s.strip
        @processor = processor.to_s.strip
      end

      attr_reader :site, :queue_name, :processor

      def run
        results = { :@site => site }

        if queue_name.empty?
          results[:jobs] = JobBoard::JobQueue.for_site(
            site: site
          )
        elsif processor.empty?
          results[:@queue] = queue_name
          results[:jobs] = [
            {
              queue: queue_name,
              jobs: JobBoard::JobQueue.for_queue(
                site: site, queue_name: queue_name
              )
            }
          ]
        else
          results[:@queue] = queue_name
          results[:@processor] = processor
          results[:jobs] = [
            {
              queue: queue_name,
              jobs: JobBoard::JobQueue.for_processor(
                site: site, queue_name: queue_name, processor: processor
              )
            }
          ]
        end

        results
      rescue JobBoard::JobQueue::Invalid => e
        { error: e, :@site => site }
      end
    end
  end
end
