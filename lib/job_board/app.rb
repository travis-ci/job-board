require 'json'

require_relative 'config'
require_relative 'models'
require_relative 'image_searcher'

require 'rack/deflater'
require 'sequel'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/param'

module JobBoard
  class App < Sinatra::Base
    helpers Sinatra::Param

    class << self
      def auth_tokens
        @auth_tokens ||= JobBoard.config.auth.tokens.split(':').map(&:strip)
      end
    end

    unless development? || test?
      require 'rack/auth/basic'

      use Rack::Auth::Basic, 'JobBoard Realm' do |_, password|
        JobBoard::App.auth_tokens.include?(password)
      end

      require 'rack/ssl'

      use Rack::SSL

    end

    use Rack::Deflater

    before do
      content_type :json
    end

    get '/' do
      redirect to('/images'), 301
    end

    get '/images' do
      param :infra, String, blank: true, required: true
      param :name, String, blank: true
      param :tags, Hash, default: {}
      param :limit, Integer, default: 1

      images = JobBoard::Services::FetchImages.run(params: params)
      data = images.map(&:to_hash)

      fields = (
        (params['fields'] || {})['images'] || ''
      ).split(',').map do |key|
        key.strip.to_sym
      end

      data = images_fields(data, fields) unless fields.empty?

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

      status 200
      json data: data,
           meta: {
             limit: limit,
             matching_query: matching_query
           }
    end

    post '/images' do
      param :infra, String, blank: true, required: true
      param :name, String, blank: true, required: true
      param :is_default, Boolean
      param :tags, Hash, default: {}

      params['is_default'] = false unless params.key?('is_default')

      image = JobBoard::Services::CreateImage.run(params: params)

      status 201
      json data: [image.to_hash]
    end

    put '/images' do
      param :infra, String, blank: true, required: true
      param :name, String, blank: true, required: true
      param :is_default, Boolean
      param :tags, Hash, default: {}

      params['is_default'] = false unless params.key?('is_default')

      image = JobBoard::Services::UpdateImage.run(params: params)
      halt 404 if image.nil?

      status 200
      json data: [image.to_hash]
    end

    delete '/images' do
      param :infra, String, blank: true, required: true
      param :name, String, blank: true, required: true
      param :tags, Hash, default: {}

      n_destroyed = JobBoard::Services::DeleteImages.run(params: params)
      halt 404 if n_destroyed == 0

      [204, {}, '']
    end

    run! if app_file == $PROGRAM_NAME

    private

    def image_searcher
      @image_searcher ||= JobBoard::ImageSearcher.new
    end

    def images_fields(images, fields)
      images.map do |image|
        image.delete_if { |k, _| !fields.include?(k) }
      end
    end

    def logger
      ::JobBoard.logger
    end
  end
end
