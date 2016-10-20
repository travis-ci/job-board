# frozen_string_literal: true
require 'json'

require_relative 'services'

require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/param'

module JobBoard
  class JobDeliveryAPI < Sinatra::Base
    helpers Sinatra::Param

    before { content_type :json }

    # FIXME: factor out these helpers
    helpers do
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

    post '/jobs' do
      param :queue, String, blank: true, required: true
      param :count, Integer, default: 1

      halt 412, JSON.dump(
        '@type' => 'error', error: 'missing from header'
      ) unless request.env.key?('HTTP_FROM')

      json JobBoard::Services::AllocateJobs.run(
        count: params[:count],
        from: request.env.fetch('HTTP_FROM'),
        jobs: JSON.parse(request.body.read).fetch('jobs'),
        queue: params[:queue]
      ).merge(
        '@count' => params[:count],
        '@queue' => params[:queue]
      )
    end

    post '/jobs/add' do
      JobBoard::Services::CreateOrUpdateJob.run(
        params: JSON.parse(request.body.read)
      )
      [201, { 'Content-Length' => '0' }, '']
    end

    get '/jobs/:job_id' do
      job = JobBoard::Services::FetchJob.run(job_id: params.fetch('job_id'))
      halt 404, JSON.dump('@type' => 'error', error: 'no such job') if job.nil?
      json job
    end

    delete '/jobs/:job_id' do
      JobBoard::Services::DeleteJob.run(job_id: params.fetch('job_id'))
      [204, {}, '']
    end
  end
end
