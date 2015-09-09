require_relative 'services/fetch_images'

module JobBoard
  class ImageSearcher
    def search(request_body)
      logger.debug("handling request request_body=#{request_body.inspect}")

      request_body.split(/\n|\r\n/).each do |line|
        images, params, limit = fetch_images_for_line(line)
        return [images, params, limit] if images.length > 0
      end

      [[], '', 1]
    end

    private

    def fetch_images_for_line(line)
      params = parse_params(line)

      return [[], 1] if missing_infra?(params)

      params['tags'] = parse_tags(params['tags']) if params.key?('tags')
      params['limit'] = limit = Integer(params['limit'] || 1)

      [fetch_images(params), params, limit]
    end

    def missing_infra?(params)
      params['infra'].nil? || params['infra'].empty?
    end

    def parse_tags(tags_string)
      Hash[tags_string.split(',').map { |t| t.split(':', 2) }]
    end

    def parse_params(line)
      logger.debug("parsing request line=#{line.inspect}")
      Hash[CGI.parse(line).map { |k, v| [k, (v.first || '').strip] }]
    end

    def fetch_images(params)
      images = ::JobBoard::Services::FetchImages.run(params: params)
      logger.debug("found images=#{images.inspect} params=#{params.inspect}")
      images
    end

    def logger
      ::JobBoard.logger
    end
  end
end