# frozen_string_literal: true

require 'openssl'

require_relative 'service'

require 'jwt'

module JobBoard
  module Services
    class CreateJWT
      extend Service

      class << self
        def job_max_duration
          @job_max_duration ||= Integer(JobBoard.config.job_max_duration)
        end
      end

      def initialize(job_id: '', site: '')
        @job_id = job_id
        @site = site
        @alg = 'RS512'
      end

      attr_reader :alg, :job_id, :site

      def run
        JWT.encode(payload, private_key, alg)
      end

      def payload
        exp = (Time.now.utc + self.class.job_max_duration).to_i
        log level: :debug, msg: 'creating jwt payload', sub: job_id,
            exp: exp, site: site
        {
          iss: "job-board/#{JobBoard.version}",
          sub: job_id,
          exp: exp,
          site: site
        }
      end

      def private_key
        JobBoard.config.jwt_private_key
      end
    end
  end
end
