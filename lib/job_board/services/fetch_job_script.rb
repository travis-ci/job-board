# frozen_string_literal: true

require 'base64'

require_relative 'service'

require 'addressable/uri'
require 'faraday'

module JobBoard
  module Services
    class FetchJobScript
      extend Service

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

        attr_writer :build_uri
      end

      def initialize(job_data: {}, caching_enabled: true, cache_ttl: 3600)
        @job_data = job_data
        @caching_enabled = caching_enabled
        @cache_ttl = cache_ttl
      end

      attr_reader :job_data, :site, :caching_enabled, :cache_ttl

      def run
        if caching_enabled
          cached_script = fetch_cached
          return cached_script unless cached_script.nil?
        end

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

        script = response.body
        store_cached(script) if caching_enabled
        script
      end

      def user_agent
        "job-board/#{JobBoard.version}"
      end

      def auth_header
        "token #{self.class.build_uri.password}"
      end

      def fetch_cached
        value = JobBoard.redis.get(cache_key)
        return nil unless value
        Base64.decode64(value)
      end

      def store_cached(script)
        JobBoard.redis.setex(
          cache_key, cache_ttl, Base64.strict_encode64(script)
        )
      end

      def cache_key
        "job_scripts:#{job_data_signature}"
      end

      def job_data_signature
        @job_data_signature ||= Digest::SHA256.hexdigest(JSON.dump(job_data))
      end
    end
  end
end
