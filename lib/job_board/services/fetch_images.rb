# frozen_string_literal: true

require 'job_board'
require_relative 'service'

require 'sequel'

module JobBoard
  module Services
    class FetchImages
      extend Service

      attr_reader :query, :infra

      def initialize(query: {})
        @query = query
        @infra = query.fetch('infra')
      end

      def run
        images = []

        build_database_query.each do |image|
          images << image.tap do |i|
            i['tags'] = i['tags'].to_hash if i['tags']
          end
        end

        images
      end

      private def build_database_query
        database_query = with_tags_matching(
          with_name_like(
            with_is_default(
              JobBoard::Models::Image.where(infra: infra)
            )
          )
        ).reverse_order(:created_at)
        limit = query.fetch('limit', 0)
        database_query = database_query.limit(limit) unless limit.zero?
        database_query
      end

      private def with_is_default(image_query)
        return image_query unless query.fetch('is_default', false)
        image_query.where(is_default: true)
      end

      private def with_name_like(image_query)
        return image_query unless query.key?('name')
        image_query.where(
          Sequel.like(:name, /#{query.fetch('name')}/)
        )
      end

      private def with_tags_matching(image_query)
        return image_query unless query.key?('tags')
        image_query.where(
          Sequel.lit('tags @> ?', Sequel.hstore(query.fetch('tags')))
        )
      end
    end
  end
end
