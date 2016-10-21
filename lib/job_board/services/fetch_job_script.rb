# frozen_string_literal: true
require 'faraday'

require_relative 'service'

module JobBoard
  module Services
    class FetchJobScript < Service
      class << self
        def build_api_conn
          @build_api_conn ||= Faraday.new(url: build_uri.to_s)
        end

        def build_uri
          @build_uri ||= URI(JobBoard.config.build_api_url)
        end
      end

      def initialize(job: {})
        @job = job
      end

      attr_reader :job, :site

      def run
        response = self.class.build_api_conn.post do |req|
          req.url '/script'
          req.headers['User-Agent'] = "job-board/#{JobBoard.version}"
          req.headers['Authorization'] = "token #{self.class.build_uri.user}"
          req.headers['Content-Type'] = 'application/json'
          req.body = JSON.dump(job)
        end

        if response.status > 299
          $stderr.puts "ERROR: build script error #{response.status} #{response.body}"
          return ''
        end

        response.body
      end
    end
  end
end
