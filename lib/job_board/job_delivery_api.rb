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

      from = request.env.fetch('HTTP_FROM')

      body = JobBoard::Services::AllocateJobs.run(
        count: params[:count],
        from: from,
        jobs: JSON.parse(request.body.read).fetch('jobs'),
        queue: params[:queue]
      ).merge(
        '@count' => params[:count],
        '@queue' => params[:queue]
      )
      $stdout.puts %(msg=allocated queue=#{params[:queue]} ) +
                   %(count=#{params[:count]} from=#{from})
      json body
    end

    post '/jobs/add' do
      job = JSON.parse(request.body.read)
      JobBoard::Services::CreateOrUpdateJob.run(params: job)
      $stdout.puts %(msg=added job_id=#{job.fetch('id')})
      [201, { 'Content-Length' => '0' }, '']
    end

    get '/jobs/:job_id' do
      job = JobBoard::Services::FetchJob.run(job_id: params.fetch('job_id'))
      halt 404, JSON.dump('@type' => 'error', error: 'no such job') if job.nil?
      $stdout.puts %(msg=fetched job_id=#{params.fetch('job_id')})
      json job
    end

    delete '/jobs/:job_id' do
      JobBoard::Services::DeleteJob.run(job_id: params.fetch('job_id'))
      $stdout.puts %(msg=deleted job_id=#{params.fetch('job_id')})
      [204, {}, '']
    end
  end
end
