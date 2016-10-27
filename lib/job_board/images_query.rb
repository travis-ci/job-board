# frozen_string_literal: true

module JobBoard
  class ImagesQuery
    def initialize(infra: '', limit: 1, name: '', is_default: false, tags: {})
      @infra = infra
      @limit = limit
      @name = name
      @is_default = is_default
      @tags = tags
    end

    attr_reader :infra, :limit, :name, :is_default, :tags

    def to_hash
      {}.tap do |h|
        h.merge!(
          'infra' => infra,
          'limit' => limit,
          'is_default' => is_default,
          'tags' => tags
        )
        h['name'] = name unless name.nil? || name.to_s.empty?
      end
    end
  end
end
