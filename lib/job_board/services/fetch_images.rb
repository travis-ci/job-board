# frozen_string_literal: true
require 'job_board'
require 'sequel'

module JobBoard
  module Services
    class FetchImages
      def self.run(params: {})
        new(params: params).run
      end

      attr_reader :params, :infra, :is_active

      def initialize(params: {})
        @params = params
        @infra = params.fetch('infra')
        @is_active = params.fetch('is_active', true)
      end

      def run
        build_query.map do |image|
          image.tap do |i|
            i['tags'] = i['tags'].to_hash if i['tags']
          end
        end
      end

      private

      def build_query
        query = with_tags_matching(
          with_name_like(
            with_is_default(
              JobBoard::Models::Image.where(infra: infra, is_active: is_active)
            )
          )
        ).reverse_order(:created_at)
        limit = params.fetch('limit', 0)
        query = query.limit(limit) unless limit.zero?
        query
      end

      def with_is_default(image_query)
        return image_query unless params.fetch('is_default', false)
        image_query.where(
          'is_default = ?', true
        )
      end

      def with_name_like(image_query)
        return image_query unless params.key?('name')
        image_query.where(
          Sequel.like(:name, /#{params.fetch('name')}/)
        )
      end

      def with_tags_matching(image_query)
        return image_query unless params.key?('tags')
        image_query.where(
          'tags @> ?', Sequel.hstore(params.fetch('tags'))
        )
      end
    end
  end
end
