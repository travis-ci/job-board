require 'job_board'
require 'sequel'

module JobBoard
  module Services
    class FetchImages
      def self.run(params: {})
        new(params: params).run
      end

      attr_reader :params, :infra

      def initialize(params: {})
        @params = params
        @infra = params.fetch('infra')
      end

      def run
        images = []

        build_query.reverse_order(:created_at).limit(
          params.fetch('limit')
        ).each do |image|
          images << image
        end

        images
      end

      private

      def build_query
        image_query = JobBoard::Models::Image.where(infra: infra)

        image_query = image_query.where(
          Sequel.like(:name, /#{params.fetch('name')}/)
        ) if params.key?('name')

        image_query = image_query.where(
          'tags @> ?', Sequel.hstore(params.fetch('tags'))
        ) if params.key?('tags')

        image_query
      end
    end
  end
end
