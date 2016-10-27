# frozen_string_literal: true

require_relative 'images_query'

module JobBoard
  class JobQueriesTransformer
    attr_reader :job_data_config, :infra, :limit

    def initialize(job_data_config: {}, infra: '', limit: 1)
      @job_data_config = job_data_config
      @infra = infra
      @limit = limit
    end

    def queries
      build_candidate_tags.map do |tags|
        JobBoard::ImagesQuery.new(
          infra: infra,
          is_default: tags.delete(:is_default) || false,
          limit: limit,
          tags: tags
        )
      end
    end

    private

    def build_candidate_tags
      full_tag_set = {}
      candidate_tags = []

      add_default_tag = proc do |tag|
        full_tag_set.merge!(tag)
        candidate_tags << { is_default: true }.merge(tag)
      end

      add_tags = proc do |tags|
        candidate_tags << { is_default: false }.merge(tags)
      end

      add_tags.call(
        osx_image: val('osx_image'),
        os: 'osx'
      ) if osx? && has?('osx_image')

      add_tags.call(
        dist: val('dist'),
        group: val('group'),
        language_key => 'true'
      ) if has?('dist', 'group', 'language')

      add_tags.call(
        dist: val('dist'),
        language_key => 'true'
      ) if has?('dist', 'language') && !osx?

      add_tags.call(
        group: val('group'),
        language_key => 'true'
      ) if has?('group', 'language')

      add_tags.call(
        os: val('os'),
        language_key => 'true'
      ) if has?('os', 'language')

      add_default_tag.call(language_key => 'true') if has?('language')
      add_default_tag.call(
        osx_image: val('osx_image')
      ) if osx? && has?('osx_image')
      add_default_tag.call(dist: val('dist')) if has?('dist')
      add_default_tag.call(group: val('group')) if has?('group')
      add_default_tag.call(os: val('os')) if has?('os')

      [full_tag_set] + candidate_tags
    end

    def val(key)
      config.fetch(key)
    end

    def has?(*keys)
      keys.all? { |key| config.fetch(key, '').to_s.strip != '' }
    end

    def osx?
      %w(osx macos).include?(config.fetch('os'))
    end

    def language_key
      :"language_#{config.fetch('language')}"
    end

    def config
      job_data_config
    end
  end
end
