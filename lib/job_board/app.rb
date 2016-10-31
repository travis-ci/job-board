# frozen_string_literal: true
# vim:fileencoding=utf-8

require_relative 'images_api'
require_relative 'job_delivery_api'

require 'rack/deflater'
require 'sinatra/base'

module JobBoard
  class App < Sinatra::Base
    use Rack::Deflater
    use JobBoard::Auth, site_paths: %r{^/jobs.+}
    use JobBoard::JobDeliveryAPI
    use JobBoard::ImagesAPI

    get '/' do
      [
        200,
        { 'Content-Type' => 'application/json' },
        JSON.dump(
          greeting: 'hello, human 👋!',
          pong: JobBoard.redis.ping.to_s,
          now: pg_now,
          version: JobBoard.version
        )
      ]
    end

    def pg_now
      JobBoard::Models.db[
        %(select now() at time zone 'UTC' as now)
      ].first.fetch(:now).utc.iso8601
    end
  end
end
