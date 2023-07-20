# frozen_string_literal: true

require_relative 'services/fetch_images'

module JobBoard
  class ImageSearcher
    def search(request_body)
      JobBoard.logger.debug(
        'handling request',
        request_body: request_body.inspect
      )

      puts '-----Inside ImageSearcher-----'
      puts "request_body: #{request_body}"
      puts '----------'
      request_body.split(/\n|\r\n/).each do |line|
        images, params, limit = fetch_images_for_line(line)
        return [images, params, limit] unless images.empty?
      end

      [[], '', 1]
    end

    private def fetch_images_for_line(line)
      params = JobBoard::ImageParams.parse(line)
      puts '-----Inside ImageSearcher#fetch_images_for_line-----'
      puts "line: #{line}"
      puts "params: #{params}"
      puts '----------'

      return [[], 1] if missing_infra?(params)

      [fetch_images(params), params, params['limit']]
    end

    private def missing_infra?(params)
      params['infra'].nil? || params['infra'].empty?
    end

    private def fetch_images(params)
      images = JobBoard::Services::FetchImages.run(query: params)
      JobBoard.logger.debug(
        'found', images: images.inspect, params: params.inspect
      )
      images
    end
  end
end
