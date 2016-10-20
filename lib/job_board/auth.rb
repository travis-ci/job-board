# frozen_string_literal: true
require 'job_board'

require 'rack/auth/abstract/handler'
require 'rack/auth/abstract/request'

module JobBoard
  class Auth < Rack::Auth::AbstractHandler
    def initialize(app, secret = nil, alg = 'RS512')
      @app = app
      @alg = alg
      @secret = secret
      @verify = true
    end

    attr_reader :alg, :secret, :verify

    def call(env)
      auth = Request.new(env)

      return unauthorized unless auth.provided?
      return bad_request unless auth.basic? || auth.bearer?

      if basic_valid?(auth)
        env['REMOTE_USER'] = auth.basic_username
        return @app.call(env)
      end

      decode_jwt!(auth)

      if bearer_valid?(auth)
        env['jwt.header'] = auth.jwt_header
        env['jwt.payload'] = auth.jwt_payload
        return @app.call(env)
      end

      unauthorized
    end

    private

    def challenge
      'Basic realm="job-board"'
    end

    def basic_valid?(auth)
      return true if auth.basic_credentials == %w(guest guest)
      auth_tokens.include?(auth.basic_credentials.last) ||
        auth_tokens.include?(auth.basic_credentials)
    end

    def bearer_valid?(auth)
      return false if auth.job_id.nil?
      return false if auth.params.empty?
      return false if auth.jwt_header.nil? || auth.jwt_payload.nil?
      true
    end

    def decode_jwt!(auth)
      auth.jwt_payload, auth.jwt_header = JWT.decode(
        auth.params, secret, verify,
        algorithm: alg, verify_sub: true, 'sub' => auth.job_id
      )
      true
    rescue JWT::InvalidSubError
      false
    rescue JWT::DecodeError
      false
    rescue JWT::ExpiredSignature
      false
    end

    def auth_tokens
      @auth_tokens ||= build_auth_tokens
    end

    def build_auth_tokens
      return raw_auth_tokens.split(':').map(&:strip) unless
      raw_auth_tokens.include?(',')

      raw_auth_tokens.split(',').map do |pair|
        pair.split(':').map(&:strip)
      end
    end

    def raw_auth_tokens
      @raw_auth_tokens ||= JobBoard.config.auth.tokens
    end

    class Request < Rack::Auth::AbstractRequest
      def job_id
        (/jobs\/(\d+)/.match(request.path_info) || [])[1]
      end

      def basic?
        'basic' == scheme
      end

      def bearer?
        'bearer' == scheme
      end

      def basic_credentials
        @basic_credentials ||= params.unpack('m*').first.split(/:/, 2)
      end

      def basic_username
        basic_credentials.first
      end

      attr_accessor :jwt_payload, :jwt_header
    end
  end
end
