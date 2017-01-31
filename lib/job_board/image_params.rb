# frozen_string_literal: true
require 'cgi'

module JobBoard
  class ImageParams
    class << self
      def parse(line)
        Hash[
          CGI.parse(line).map { |k, v| [k, (v.first || '').strip] }
        ].tap do |params|
          params['tags'] = parse_tags(params['tags']) if params.key?('tags')
          params['limit'] = Integer(params['limit'] || 1)
          params['is_default'] = parse_bool(params['is_default'] || false)
        end
      end

      private def parse_tags(tags_string)
        Hash[tags_string.split(',').map { |t| t.split(':', 2) }]
      end

      private def parse_bool(bool_string)
        %w(yes true on 1).include?(bool_string.to_s.downcase)
      end
    end
  end
end
