# frozen_string_literal: true
require_relative 'services/fetch_images'

require 'l2met-log'

module JobBoard
  class ImageSearcher
    include L2met::Log

    def search(request_body)
      log level: :debug, msg: 'handling request',
          request_body: request_body.inspect

      request_body.split(/\n|\r\n/).each do |line|
        images, params, limit = fetch_images_for_line(line)
        return [images, params, limit] unless images.empty?
      end

      [[], '', 1]
    end

    private

    def fetch_images_for_line(line)
      params = JobBoard::ImageParams.parse(line)

      return [[], 1] if missing_infra?(params)

      [fetch_images(params), params, params['limit']]
    end

    def missing_infra?(params)
      params['infra'].nil? || params['infra'].empty?
    end

    def fetch_images(params)
      images = JobBoard::Services::FetchImages.run(query: params)
      log level: :debug, msg: 'found',
          images: images.inspect, params: params.inspect
      images
    end
  end
end
