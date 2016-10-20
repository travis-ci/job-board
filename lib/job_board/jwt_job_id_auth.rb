# frozen_string_literal: true
# Lifted from https://auth0.com/blog/ruby-authentication-secure-rack-apps-with-jwt/
# plus modifications :heart_eyes_cat:

module JobBoard
  class JWTJobIDAuth
    def initialize(app, secret, alg = 'RS512')
      @alg = alg
      @app = app
      @secret = secret
      @verify = true
    end

    attr_reader :alg, :secret, :verify

    def call(env)
      job_id, response = validate(env)
      env['job_board.jwt.job_id'] = job_id
      response
    end

    def validate(env)
      path_job_id = (/jobs\/(\d+)/.match(env.fetch('PATH_INFO', '')) || [])[0]

      return '', json_err(
        400, 'no job id present in path'
      ) if path_job_id.nil?

      return '', json_err(
        400, 'no authorization header'
      ) unless env.key?('HTTP_AUTHORIZATION')

      bearer = env.fetch('HTTP_AUTHORIZATION', '').slice(7..-1)
      payload, header = JWT.decode(
        bearer, secret, verify, algorithm: alg
      )
      job_id = payload['sub']

      return '', json_err(
        403, 'job ids do not match'
      ) unless path_job_id == job_id

      return job_id, []
    rescue JWT::DecodeError
      [false, '', json_err(401, 'missing token')]
    rescue JWT::ExpiredSignature
      [false, '', json_err(403, 'token expired')]
    end

    private

    def json_err(status, error)
      [
        status,
        { 'Content-Type' => 'application/json' },
        JSON.dump('@type' => 'error', 'error' => error)
      ]
    end
  end
end
