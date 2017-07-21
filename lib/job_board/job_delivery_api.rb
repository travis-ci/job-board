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
    end

    post '/jobs' do
      param :queue, String, blank: true, required: true
      param :count, Integer, default: 1
      param :capacity, Integer

      unless request.env.key?('HTTP_FROM')
        halt 412, JSON.dump(
          '@type' => 'error', error: 'missing from header'
        )
      end

      queue = params[:queue].to_s.sub(/^builds\./, '')
      from = request.env.fetch('HTTP_FROM')
      site = request.env.fetch('travis.site')

      jobs = JSON.parse(request.body.read).fetch('jobs')
      capacity = params[:capacity] || (params[:count] + jobs.length)

      body = JobBoard::Services::AllocateJobs.run(
        capacity: capacity,
        from: from,
        jobs: jobs,
        queue_name: queue,
        site: site
      ).merge(
        '@capacity' => capacity,
        '@queue' => queue
      )
      JobBoard.logger.info(
        'allocated',
        queue: queue, capacity: capacity, from: from, site: site
      )
      json body
    end

    post '/jobs/add' do
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
      JobBoard.logger.info('fetched', job_id: job_id, site: site, infra: infra)
      json job
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

    delete '/jobs/:job_id' do
      job_id = params.fetch('job_id')
      site = request.env.fetch('travis.site')
      JobBoard::Services::DeleteJob.run(job_id: job_id, site: site)
      JobBoard.logger.info('deleted', job_id: job_id, site: site)
      [204, {}, '']
    end
  end
end
