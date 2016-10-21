# frozen_string_literal: true
require 'addressable/uri'
require 'faraday'

require_relative 'service'

module JobBoard
  module Services
    class FetchJobScript < Service
      BuildScriptError = Class.new(StandardError)

      class << self
        def build_api_conn
          @build_api_conn ||= Faraday.new(url: build_uri.to_s)
        end

        def build_uri
          @build_uri ||= Addressable::URI.parse(
            JobBoard.config.build_api_url
          )
        end
      end

      def initialize(job_data: {})
        @job_data = job_data
      end

      attr_reader :job_data, :site

      def run
        response = self.class.build_api_conn.post do |req|
          req.url '/script'
          req.headers['User-Agent'] = user_agent
          req.headers['Authorization'] = auth_header
          req.headers['Content-Type'] = 'application/json'
          req.body = JSON.dump(job_data)
        end

        if response.status > 299
          log level: :error, msg: 'build script error',
              status: response.status, body: response.body,
              job_data_length: JSON.dump(job_data).length
          return BuildScriptError.new(response.body)
        end

        response.body
      end

      def user_agent
        "job-board/#{JobBoard.version}"
      end

      def auth_header
        "token #{self.class.build_uri.password}"
      end
    end
  end
end
