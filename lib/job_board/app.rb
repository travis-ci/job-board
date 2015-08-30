require 'json'
require 'logger'

require_relative 'config'
require_relative 'models'

require 'rack/auth/basic'
require 'rack/ssl'
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
      use Rack::Auth::Basic, 'JobBoard Realm' do |_, password|
        JobBoard::App.auth_tokens.include?(password)
      end

      use Rack::SSL
    end

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

      param :slug, String, blank: true
      param :owner, String, blank: true
      param :os, String, blank: true
      param :language, String, blank: true
      param :dist, String, blank: true, default: 'precise'
      param :osx_image, String, blank: true
      param :services, Array, blank: true

      images = JobBoard::Services::FetchImages.run(params: params)

      status 200
      json data: images.map(&:to_hash),
           meta: {
             limit: params.fetch('limit')
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

    put '/images/:id' do
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

    run! if app_file == $PROGRAM_NAME
  end
end
