# frozen_string_literal: true

require_relative 'image_params'
require_relative 'models'
require_relative 'services/update_image'

module JobBoard
  class ImageUpdater
    def update(request_body)
      JobBoard.logger.debug(
        'handling request', request_body: request_body.inspect
      )

      images = []
      errors = []

      JobBoard::Models.db.transaction do
        images = request_body.split(/\n|\r\n/).map do |line|
          params = JobBoard::ImageParams.parse(line)

          unless JobBoard::ImageParams.valid?(params)
            errors << "invalid params hash=#{params.inspect}"
            raise Sequel::Rollback
          end

          image = JobBoard::Services::UpdateImage.run(params: params)

          if image.nil?
            errors << "failed to update image with name=#{params['name']}"
            raise Sequel::Rollback
          end

          image
        end
      end

      [images.compact, errors.compact]
    end
  end
end
