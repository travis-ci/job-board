# frozen_string_literal: true
module JobBoard
  module Services
    class DeleteImages
      def self.run(params: {})
        new(params: params).run
      end

      attr_reader :params

      def initialize(params: {})
        @params = params
      end

      def run
        images = by_infra_and_name
        return nil if images.empty?
        JobBoard::Models.db.transaction do
          archive_images(images)
          images.destroy
        end
      end

      private

      def by_infra_and_name
        JobBoard::Models::Image.where(
          infra: params.fetch('infra'),
          name: params.fetch('name')
        )
      end

      def archive_images(images)
        images.each do |image|
          JobBoard::Models::ArchivedImage.create(
            original_id: image.id,
            name: image.name,
            infra: image.infra
          )
        end
      end
    end
  end
end
