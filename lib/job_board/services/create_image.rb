module JobBoard
  module Services
    class CreateImage
      attr_reader :params

      def initialize(params: {})
        @params = params
      end

      def run
        JobBoard::Models::Image.create(
          infra: params.fetch('infra'),
          name: params.fetch('name'),
          is_default: params.fetch('is_default'),
          tags: Sequel.hstore(params.fetch('tags'))
        )
      end
    end
  end
end
