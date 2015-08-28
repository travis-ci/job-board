require 'json'
require 'logger'

require 'pg'
require 'sequel'
require 'sequel/model'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/param'

class IMGRef < Sinatra::Base
  helpers Sinatra::Param

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
    param :limit, Fixnum, default: 1

    param :slug, String, blank: true
    param :owner, String, blank: true
    param :os, String, blank: true
    param :language, String, blank: true
    param :dist, String, blank: true, default: 'precise'
    param :osx_image, String, blank: true
    param :services, Array, blank: true

    image_query = Image.where(infra: params.fetch('infra'))
    override_query = Override

    %w(slug owner os language dist osx_image).each do |key|
      if params.key?(key)
        override_query = override_query.where(key => params.fetch(key))
      end
    end

    if params.key?('services')
      override_query = override_query.where('services && ?', params.fetch('services'))
    end

    images = []

    if override_query.count > 0
      override_query.reverse_order(:importance).each { |override| images << override.image }
    else
      if params.key?('tags')
        image_query = image_query.where('tags @> ?', Sequel.hstore(params.fetch('tags')))
      end

      image_query.reverse_order(:created_at).limit(params.fetch('limit')).each do |image|
        images << image
      end
    end

    if images.empty?
      default_image = Image.where(infra: params.fetch('infra'), is_default: true).first
      images << default_image if default_image
    end

    status 200
    json images: images.map(&:to_hash)
  end

  post '/images' do
    param :infra, String, blank: true, required: true
    param :name, String, blank: true, required: true
    param :is_default, Boolean, default: false
    param :tags, Hash, default: {}

    img = Image.create(
      infra: params.fetch('infra'),
      name: params.fetch('name'),
      is_default: params.fetch('is_default'),
      tags: Sequel.hstore(params.fetch('tags'))
    )

    status 201
    json images: [img.to_hash]
  end

  put '/images/:id' do
    param :infra, String, blank: true, required: true
    param :name, String, blank: true, required: true
    param :is_default, Boolean, default: false
    param :tags, Hash, default: {}

    img = Image[params.fetch('id')]
    halt 404 if img.nil?

    img.update(
      infra: params.fetch('infra'),
      name: params.fetch('name'),
      is_default: params.fetch('is_default'),
      tags: Sequel.hstore(params.fetch('tags'))
    )

    status 200
    json images: [img.to_hash]
  end

  def db
    self.class.db
  end

  class << self
    def db
      @db ||= Sequel.connect(
        db_url,
        max_connections: db_max_connections,
        logger: db_logger
      )
    end

    def db_url
      @db_url ||= (ENV['DATABASE_URL'] || 'postgres://localhost:5432/')
    end

    def db_max_connections
      @db_max_connections ||= Integer(
        ENV.values_at('DB_POOL', 'DATABASE_POOL_SIZE').compact.first || 25
      )
    end

    def db_logger
      @db_logger ||= (ENV['SQL_LOGGING'] ? Logger.new($stderr) : nil)
    end

    def initdb!
      Sequel.extension :core_extensions, :pg_hstore

      %w(images overrides).each do |table|
        :"imgref__#{table}"
        Sequel.qualify(:imgref, table.to_sym)
        table.to_sym.qualify(:imgref)
      end

      db['select now()']
    end
  end

  initdb!
  run! if app_file == $PROGRAM_NAME
end


class Image < Sequel::Model(:imgref__images)
  set_primary_key :id

  plugin :timestamps, update_on_create: true
end

class Override < Sequel::Model(:imgref__overrides)
  many_to_one :image
  set_primary_key :id

  plugin :timestamps, update_on_create: true
end
