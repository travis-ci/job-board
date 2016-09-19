# frozen_string_literal: true
require 'job_board'
require 'sequel'

module JobBoard
  module Services
    class ActivateImages
      def self.run(params: {})
        new(params: params).run
      end

      attr_reader :params, :infra

      def initialize(params: {})
        @params = params
        @infra = params.fetch('infra')
      end

      def run
        images = build_query.map do |image|
          image.tap do |i|
            i['tags'] = i['tags'].to_hash if i['tags']
          end
        end

        JobBoard::Models.db.transaction do
          images.each { |image| image.update(is_active: params[:is_active]) }
        end

        images
      end

      private

      def build_query
        with_name_like(
          JobBoard::Models::Image.where(infra: infra)
        ).reverse_order(:created_at)
      end

      def with_name_like(image_query)
        return image_query unless params.key?('name')
        image_query.where(
          Sequel.like(:name, /#{params.fetch('name')}/)
        )
      end
    end
  end
end
