# frozen_string_literal: true
require 'json'

require_relative 'services'
require_relative '../l2met_log'

require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/param'

module JobBoard
  class JobDeliveryAPI < Sinatra::Base
    helpers Sinatra::Param

    before { content_type :json }

    # FIXME: factor out these helpers
    helpers do
      include L2metLog

      def guest?
        (env['REMOTE_USER'] || 'notset') == 'guest'
      end

      def set_images_mutation_params
        param :infra, String, blank: true, required: true
        param :is_default, Boolean
        param :tags, Hash, default: {}
        param :name, String, blank: true, required: true,
                             format: images_name_format
      end

      def images_name_format
        @images_name_format ||= /#{JobBoard.config.images_name_format}/
      end
    end

    before '/jobs*' do
      halt 403, JSON.dump('@type' => 'error', error: 'just no') if guest?
    end

    post '/jobs' do
      param :queue, String, blank: true, required: true
      param :count, Integer, default: 1

      halt 412, JSON.dump(
        '@type' => 'error', error: 'missing from header'
      ) unless request.env.key?('HTTP_FROM')

      from = request.env.fetch('HTTP_FROM')
      site = request.env.fetch('travis.site')

      body = JobBoard::Services::AllocateJobs.run(
        count: params[:count],
        from: from,
        jobs: JSON.parse(request.body.read).fetch('jobs'),
        queue: params[:queue],
        site: site
      ).merge(
        '@count' => params[:count],
        '@queue' => params[:queue]
      )
      log msg: :allocated, queue: params[:queue],
          count: params[:count], from: from, site: site
      json body
    end

    post '/jobs/add' do
      job = JSON.parse(request.body.read)
      site = request.env.fetch('travis.site')
      db_job = JobBoard::Services::CreateOrUpdateJob.run(job: job, site: site)
      halt 400, JSON.dump('@type' => 'error', error: 'what') if db_job.nil?
      log msg: :added, job_id: job.fetch('id'), site: site
      [201, { 'Content-Length' => '0' }, '']
    end

    get '/jobs/:job_id' do
      job_id = params.fetch('job_id')
      site = request.env.fetch('travis.site')
      job = JobBoard::Services::FetchJob.run(job_id: job_id, site: site)
      halt 404, JSON.dump('@type' => 'error', error: 'no such job') if job.nil?
      halt 424, JSON.dump(
        '@type' => 'error',
        error: 'job script fetch error',
        upstream_error: job.message
      ) if job.is_a?(JobBoard::Services::FetchJobScript::BuildScriptError)
      log msg: :fetched, job_id: job_id, site: site
      json job.fetch('data')
    end

    delete '/jobs/:job_id' do
      job_id = params.fetch('job_id')
      site = request.env.fetch('travis.site')
      JobBoard::Services::DeleteJob.run(job_id: job_id, site: site)
      log msg: :deleted, job_id: job_id, site: site
      [204, {}, '']
    end
  end
end
