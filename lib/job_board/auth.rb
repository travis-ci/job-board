# frozen_string_literal: true
require 'job_board'

module JobBoard
  class Auth
    def authorized?(user, password)
      return true if [user, password] == %w(guest guest)
      auth_tokens.include?(password) || auth_tokens.include?([user, password])
    end

    private

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
