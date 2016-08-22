# frozen_string_literal: true
require 'job_board'

require 'rack/auth/basic'

module JobBoard
  class Auth < Rack::Auth::Basic
    def initialize(app)
      @app = app
      @realm = 'job-board'
    end

    private

    attr_reader :realm

    def valid?(auth)
      return true if auth.credentials == %w(guest guest)
      auth_tokens.include?(auth.credentials.last) ||
        auth_tokens.include?(auth.credentials)
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
  end
end
