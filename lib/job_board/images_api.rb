# frozen_string_literal: true

require_relative 'auth'
require_relative 'image_searcher'
require_relative 'services'

require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/param'

module JobBoard
  class ImagesAPI < Sinatra::Base
    helpers Sinatra::Param

    before { content_type :json }

    helpers do
      include JobBoard::Auth::GuestDetect

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

    get '/images' do
      param :infra, String, blank: true, required: true
      param :name, String, blank: true
      param :tags, Hash, default: {}
      param :limit, Integer, default: 0
      param :is_default, Boolean, default: false

      puts '----------'
      puts 'sb-jobboard-images-debugging GET /images'
      puts params

      images = JobBoard::Services::FetchImages.run(query: params)
      data = images.map(&:to_hash)

      fields = (
        (params['fields'] || {})['images'] || ''
      ).split(',').map do |key|
        key.strip.to_sym
      end

      data = images_fields(data, fields) unless fields.empty?

      puts 'response data in GET /images'
      puts data
      puts '----------'

      status 200
      json data: data,
           meta: {
             limit: params.fetch('limit')
           }
    end

    # This is a POST-ish version of `GET /images` that accepts a body of
    # line-delimited queries, returning with the first query with results
    post '/images/search' do
      images, matching_query, limit = image_searcher.search(request.body.read)
      data = images.map(&:to_hash)

      fields = (matching_query['fields[images]'] || '').split(',').map do |key|
        key.strip.to_sym
      end

      data = images_fields(data, fields) unless fields.empty?

      puts '----------'
      puts 'sb-jobboard-images-debugging /images/search'
      puts "request body: #{request.body.read}"
      puts "response data: #{data}"
      puts '----------'
      status 200
      json data: data,
           meta: { limit: limit, matching_query: matching_query }
    end

    post '/images' do
      halt 403 if guest?

      set_images_mutation_params

      params['is_default'] = false unless params.key?('is_default')

      image = JobBoard::Services::CreateImage.run(params: params)

      puts '----------'
      puts 'sb-jobboard-images-debugging in POST /images'
      puts "params: #{params}"
      puts "created image: #{image}"
      puts '----------'
      status 201
      json data: [image.to_hash]
    end

    put '/images' do
      halt 403 if guest?

      set_images_mutation_params

      params['is_default'] = false unless params.key?('is_default')

      image = JobBoard::Services::UpdateImage.run(params: params)
      puts '----------'
      puts 'sb-jobboard-images-debugging PUT /images'
      puts "params: #{params}"
      puts "Updated image: #{image}"
      puts '----------'
      halt 404 if image.nil?

      status 200
      json data: [image.to_hash]
    end

    # This is a multi-image version of `PUT /images` that accepts a body of
    # line-delimited requests, wrapping the whole thing up in a database-level
    # transaction.
    put '/images/multi' do
      halt 403 if guest?

      images, errors = image_updater.update(request.body.read)
      puts '----------'
      puts 'sb-jobboard-images-debugging PUT /images/multi'
      puts "request body: #{request.body.read}"
      puts "multi images: #{images}"
      puts '----------'
      halt 400, JSON.dump(error: errors) if images.nil? || images.empty?

      status 200
      json data: images.map(&:to_hash)
    end

    delete '/images' do
      halt 403 if guest?

      set_images_mutation_params

      n_destroyed = JobBoard::Services::DeleteImages.run(params: params)
      puts '----------'
      puts 'sb-jobboard-images-debugging DELETE /images'
      puts "request body: #{request.body.read}"
      puts "deleted image: #{n_destroyed}"
      puts '----------'
      halt 404 if n_destroyed.nil? || n_destroyed.zero?

      [204, {}, '']
    end

    private def image_searcher
      @image_searcher ||= JobBoard::ImageSearcher.new
    end

    private def image_updater
      @image_updater ||= JobBoard::ImageUpdater.new
    end

    private def images_fields(images, fields)
      images.map do |image|
        image.delete_if { |k, _| !fields.include?(k) }
      end
    end
  end
end
