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

module CareerCenter
  class App < Sinatra::Base
    helpers Sinatra::Param

    class << self
      def auth_tokens
        @auth_tokens ||= CareerCenter.config.auth.tokens.split(':').map(&:strip)
      end
    end

    unless development?
      use Rack::Auth::Basic, 'CareerCenter Realm' do |_, password|
        CareerCenter::App.auth_tokens.include?(password)
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

      images = CareerCenter::Services::FetchImages.new(params: params).run

      status 200
      json images: images.map(&:to_hash)
    end

    post '/images' do
      param :infra, String, blank: true, required: true
      param :name, String, blank: true, required: true
      param :is_default, Boolean, default: false
      param :tags, Hash, default: {}

      image = CareerCenter::Services::CreateImage.new(params: params).run

      status 201
      json images: [image.to_hash]
    end

    put '/images/:id' do
      param :infra, String, blank: true, required: true
      param :name, String, blank: true, required: true
      param :is_default, Boolean, default: false
      param :tags, Hash, default: {}

      image = CareerCenter::Services::UpdateImage.new(params: params).run
      halt 404 if image.nil?

      status 200
      json images: [image.to_hash]
    end

    run! if app_file == $PROGRAM_NAME
  end
end
