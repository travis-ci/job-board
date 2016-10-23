# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class DeleteImages
      extend Service

      attr_reader :params

      def initialize(params: {})
        @params = params
      end

      def run
        images = by_infra_and_name
        return nil if images.empty?
        images.destroy
      end

      private

      def by_infra_and_name
        JobBoard::Models::Image.where(
          infra: params.fetch('infra'),
          name: params.fetch('name')
        )
      end
    end
  end
end
