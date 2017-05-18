# frozen_string_literal: true

require 'base64'
require 'openssl'

require_relative 'service'

require 'jwt'

module JobBoard
  module Services
    class CreateJWT
      extend Service

      class << self
        def private_key
          @private_key ||= OpenSSL::PKey::RSA.new(
            Base64.decode64(JobBoard.config.jwt_private_key)
          )
        end

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
        {
          iss: "job-board/#{JobBoard.version}",
          sub: job_id,
          exp: (Time.now.utc + self.class.job_max_duration).to_i,
          site: site
        }
      end

      def private_key
        self.class.private_key
      end
    end
  end
end
