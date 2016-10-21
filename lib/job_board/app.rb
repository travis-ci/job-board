# frozen_string_literal: true

require_relative 'images_api'
require_relative 'job_delivery_api'

require 'rack/deflater'
require 'sinatra/base'

module JobBoard
  class App < Sinatra::Base
    use Rack::Deflater
    use JobBoard::Auth, site_paths: %r{^/jobs.+}
    use JobBoard::JobDeliveryAPI
    use JobBoard::ImagesAPI
  end
end
