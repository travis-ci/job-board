require 'sequel'

module CareerCenter
  module Services
    class UpdateImage
      attr_reader :params

      def initialize(params: {})
        @params = params
      end

      def run
        image = CareerCenter::Models::Image[params.fetch('id')]
        return nil if image.nil?

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
