# frozen_string_literal: true
require 'sequel'

module JobBoard
  module Services
    class UpdateImage
      def self.run(params: {})
        new(params: params).run
      end

      attr_reader :params

      def initialize(params: {})
        @params = params
      end

      def run
        image = by_infra_and_name
        return nil if image.nil?
        update_image(image)
      end

      private

      def by_infra_and_name
        JobBoard::Models::Image.where(
          infra: params.fetch('infra'),
          name: params.fetch('name')
        ).first
      end

      def update_image(image)
        image.update(
          infra: params.fetch('infra'),
          name: params.fetch('name'),
          is_default: params.fetch('is_default'),
          tags: Sequel.hstore(params.fetch('tags'))
        )

        image
      end
    end
  end
end
