# frozen_string_literal: true

require 'json'

require_relative 'auth'
require_relative 'services'

require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/param'

module JobBoard
  class JobDeliveryAPI < Sinatra::Base
    helpers Sinatra::Param

    before { content_type :json }

    helpers do
      include JobBoard::Auth::GuestDetect
    end

    before '/jobs*' do
      halt 403, JSON.dump('@type' => 'error', error: 'just no') if guest?
      headers(interval_headers)
    end

    post '/jobs' do
      JobBoard.logger.debug('received legacy jobs request', source: source)
      json(jobs: [], unavailable_jobs: [])
    end

    post '/jobs/add' do
      request.body.rewind if request.body.respond_to?(:rewind)
      job = JSON.parse(request.body.read)
      site = request.env.fetch('travis.site')
      JobBoard.logger.debug(
        'parsed job',
        job_id: job.fetch('id', '<unknown>'), site: site
      )
      db_job = JobBoard::Services::CreateOrUpdateJob.run(job: job, site: site)
      if db_job.nil?
        JobBoard.logger.error(
          'failed to create or update job',
          job_id: job.fetch('id'), site: site
        )
        halt 400, JSON.dump('@type' => 'error', error: 'what')
      end
      JobBoard.logger.info('added', job_id: job.fetch('id'), site: site)
      [201, { 'Content-Length' => '0' }, '']
    end

    post '/jobs/pop' do
      param :queue, String, blank: true, required: true

      unless request.env.key?('HTTP_FROM')
        halt 412, JSON.dump(
          '@type' => 'error', error: 'missing from header'
        )
      end

      queue = params[:queue].to_s.sub(/^builds\./, '')
      site = request.env.fetch('travis.site')

      job_id = JobBoard::Services::AllocateJob.run(
        from: from,
        queue_name: queue,
        site: site
      )

      if job_id.nil?
        JobBoard.logger.debug(
          'no jobs available',
          queue: queue, from: from, site: site
        )
        halt 204
      end

      JobBoard.logger.info(
        'popped',
        queue: queue, from: from, site: site, job_id: job_id
      )

      status 200
      json('@queue' => queue, 'job_id' => job_id)
    end

    post '/jobs/:job_id/claim' do
      param :queue, String, blank: true, required: true

      queue = params[:queue].to_s.sub(/^builds\./, '')
      site = request.env.fetch('travis.site')
      job_id = params[:job_id]

      unless request.env.key?('HTTP_FROM')
        JobBoard.logger.warn(
          'missing from header',
          job_id: job_id,
          queue: queue,
          site: site
        )

        halt 412, JSON.dump(
          '@type' => 'error', error: 'missing from header'
        )
      end

      unless JobBoard::Services::RefreshJobClaim.run(
        job_id: job_id,
        from: from,
        queue_name: queue,
        site: site
      )
        JobBoard.logger.warn(
          'job id is not claimed',
          job_id: job_id, queue: queue, from: from, site: site
        )
        halt 409
      end

      JobBoard.logger.debug(
        'claim refreshed',
        queue: queue, from: from, site: site, job_id: job_id
      )
      status 200
      json('@queue' => queue, '@job_id' => job_id)
    end

    get '/jobs/:job_id' do
      job_id = params.fetch('job_id')
      site = request.env.fetch('travis.site')
      infra = request.env.fetch('travis.infra', '')
      job = JobBoard::Services::FetchJob.run(
        job_id: job_id, site: site, infra: infra
      )
      halt 404, JSON.dump('@type' => 'error', error: 'no such job') if job.nil?
      if job.is_a?(JobBoard::Services::FetchJobScript::BuildScriptError)
        halt 424, JSON.dump(
          '@type' => 'error',
          error: 'job script fetch error',
          upstream_error: job.message
        )
      end
      JobBoard.logger.info(
        'fetched', job_id: job_id, site: site, infra: infra, source: source
      )
      json job
    end

    delete '/jobs/:job_id' do
      job_id = params.fetch('job_id')
      site = request.env.fetch('travis.site')
      JobBoard::Services::DeleteJob.run(job_id: job_id, site: site)
      JobBoard.logger.info('deleted', job_id: job_id, site: site, source: source)
      [204, {}, '']
    end

    def from
      request.env.fetch('HTTP_FROM')
    end

    def source
      request.env.fetch(
        'HTTP_FROM',
        params.fetch(
          'source',
          request.env.fetch('REMOTE_ADDR', '???')
        )
      )
    end

    private def interval_headers
      {
        'Travis-Pop-Interval' => JobBoard.config.processor_pop_interval.to_s,
        'Travis-Refresh-Claim-Interval' => Integer(
          JobBoard.config.processor_ttl / 2
        ).to_s
      }
    end
  end
end
