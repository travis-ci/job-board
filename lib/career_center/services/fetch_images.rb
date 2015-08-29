require 'career_center'
require 'sequel'

module CareerCenter
  module Services
    class FetchImages
      attr_reader :params, :infra

      def initialize(params: {})
        @params = params
        @infra = params.fetch('infra')
      end

      def run
        image_query = CareerCenter::Models::Image.where(infra: infra)
        override_query = CareerCenter::Models::Override

        %w(slug owner os language dist osx_image).each do |key|
          if params.key?(key)
            override_query = override_query.where(key => params.fetch(key))
          end
        end

        if params.key?('services')
          override_query = override_query.where(
            'services && ?', params.fetch('services')
          )
        end

        images = []

        if override_query.count > 0
          override_query.reverse_order(:importance).each do |override|
            images << override.image
          end
        else
          if params.key?('tags')
            image_query = image_query.where(
              'tags @> ?', Sequel.hstore(params.fetch('tags'))
            )
          end

          limit = params.fetch('limit')
          image_query.reverse_order(:created_at).limit(limit).each do |image|
            images << image
          end
        end

        if images.empty?
          default_image = CareerCenter::Models::Image.where(
            infra: infra, is_default: true
          ).first
          images << default_image if default_image
        end

        images
      end
    end
  end
end
