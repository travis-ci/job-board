require 'json'
require 'logger'

require_relative 'config'
require_relative 'models'

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

      def logger
        @logger ||= Logger.new($stdout).tap do |l|
          $stdout.sync = true
          l.level = Logger::DEBUG
        end
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

      status 200
      json data: images.map(&:to_hash),
           meta: {
             limit: params.fetch('limit')
           }
    end

    # This is a POST-ish version of `GET /images` that accepts a body of
    # line-delimited queries, returning with the first query with results
    post '/images/search' do
      puts 'Handling POST /images/search'
      images, limit = fetch_images_from_body(request.body)
      status 200
      json data: images.map(&:to_hash),
           meta: {
             limit: limit
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

    run! if app_file == $PROGRAM_NAME

    private

    def fetch_images_from_body(request_body)
      logger.debug("received request_body=#{request_body.inspect}")
      puts("received request_body=#{request_body.inspect}")
      images = []
      limit = 1

      request_body.each_line do |line|
        line_params = Hash[
          CGI.parse(line).map { |key, values| [key, values.first || ''] }
        ]

        next if line_params['infra'].nil? || line_params['infra'].empty?

        if line_params.key?('tags')
          line_params['tags'] = Hash[
            line_params['tags'].split(',').map { |t| t.split(':', 2) }
          ]
        end

        line_params['limit'] = limit = Integer(line_params['limit'] || 1)

        images = JobBoard::Services::FetchImages.run(params: line_params)
        return images, limit if images.length > 0
      end

      logger.debug("returning images=#{images.inspect} limit=#{limit.inspect}")
      puts("returning images=#{images.inspect} limit=#{limit.inspect}")
      [images, limit]
    end

    def logger
      self.class.logger
    end
  end
end
