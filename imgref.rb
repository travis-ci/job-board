require 'pg'
require 'sequel'
require 'sequel/model'
require 'sinatra/base'
require 'sinatra/json'

class IMGRef < Sinatra::Base
  get '/' do
    'ohai'
  end

  get '/images' do
    status 200
    json images: []
  end

  post '/images' do
    status 201

    json images: []
  end

  put '/images/:id' do
    status 200
    json images: []
  end

  class << self
    def db
      @db ||= Sequel.connect(db_url, max_connections: max_connections)
    end

    def db_url
      @db_url ||= (ENV['DATABASE_URL'] || 'postgres://localhost:5432/')
    end

    def max_connections
      @max_connections ||= Integer(
        ENV.values_at('DB_POOL', 'DATABASE_POOL_SIZE').compact.first || 25
      )
    end
  end

  run! if app_file == $PROGRAM_NAME
end

IMGRef.db['select now()']

class Image < Sequel::Model
  plugin :timestamps, update_on_create: true
end
