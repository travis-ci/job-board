# frozen_string_literal: true
require 'job_board'
require 'sequel'

module JobBoard
  module Services
    class RestoreImage
      NoExactMatch = Class.new(StandardError)

      def self.run(params: {})
        new(params: params).run
      end

      attr_reader :params

      def initialize(params: {})
        @params = params
      end

      def run
        images = find_matching_images
        raise NoExactMatch, params if images.count != 1
        restore(images.fetch(0))
      end

      def restore(image)
        created = nil
        JobBoard::Models.db.transaction do
          created = JobBoard::Services::CreateImage.run(
            params: stringified(image)
          )
          image.destroy
        end
        created
      end

      private

      def find_matching_images
        JobBoard::Services::FetchImages.run(
          params: params, model: JobBoard::Models::ArchivedImage
        )
      end

      def stringified(image)
        image.dup.to_hash.tap do |h|
          h.dup.keys.each do |k|
            h[k.to_s] = h.delete(k)
          end
        end
      end
    end
  end
end
