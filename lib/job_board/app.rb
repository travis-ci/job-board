# frozen_string_literal: true

# vim:fileencoding=utf-8

require_relative 'images_api'
require_relative 'job_delivery_api'

require 'rack/deflater'
require 'sinatra/base'
require 'sinatra/param'

module JobBoard
  class App < Sinatra::Base
    helpers Sinatra::Param

    configure do
      enable :logging if JobBoard.config.api_logging?
    end

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
          pong: JobBoard.redis_pool.with { |c| c.ping.to_s },
          now: pg_now,
          version: JobBoard.version
        )
      ]
    end

    get '/latest-stats' do
      [
        200,
        { 'Content-Type' => 'application/json' },
        JobBoard.redis_pool.with { |c| c.get('latest-stats') }
      ]
    end

    get '/search/jobs/:site' do
      param :worker, String, default: nil
      param :queue, String, default: nil

      results = JobBoard::Services::SearchJobs.new(
        site: params[:site],
        queue_name: params[:queue],
        worker: params[:worker]
      ).run

      status 400 unless results[:error].nil?
      json results
    end

    def pg_now
      JobBoard::Models.db[
        %(select now() at time zone 'UTC' as now)
      ].first.fetch(:now).utc.iso8601
    end
  end
end
