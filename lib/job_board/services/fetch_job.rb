# frozen_string_literal: true
require 'base64'

require 'job_board'
require_relative 'service'
require_relative '../job_queries_transformer'

require 'addressable/template'

module JobBoard
  module Services
    class FetchJob
      extend Service

      def initialize(job_id: '', site: '', infra: '')
        @job_id = job_id.to_s
        @site = site.to_s
        @infra = infra.to_s
      end

      attr_reader :job_id, :site, :infra

      def run
        return nil if job_id.empty? || site.empty?

        job = {}
        db_job = fetch_db_job
        return nil unless db_job

        job.merge!(db_job.data)

        job_script_content = fetch_job_script(
          job.fetch('data').merge(
            config.build.to_hash.merge(
              'paranoid' => paranoid?(db_job.queue)
            )
          )
        )

        if job_script_content.is_a?(
          JobBoard::Services::FetchJobScript::BuildScriptError
        )
          return job_script_content
        end

        job.merge!(
          job_script: {
            name: 'main',
            encoding: 'base64',
            content: Base64.encode64(job_script_content).split.join
          },
          job_state_url: job_id_url('job_state_%{site}_url'),
          log_parts_url: job_id_url('log_parts_%{site}_url'),
          jwt: generate_jwt,
          image_name: fetch_image_name(job)
        )
        cleaned(job.merge('@type' => 'job_board_job'))
      end

      def fetch_db_job
        log msg: 'fetching job from database',
            job_id: job_id, site: site, infra: infra
        JobBoard::Models::Job.first(job_id: job_id, site: site)
      end

      def fetch_job_script(job_data)
        log msg: 'fetching job script',
            job_id: job_id, site: site, infra: infra
        JobBoard::Services::FetchJobScript.run(job_data: job_data)
      end

      def generate_jwt
        log msg: 'creating jwt',
            job_id: job_id, site: site, infra: infra
        JobBoard::Services::CreateJWT.run(
          job_id: job_id, site: site
        )
      end

      def fetch_image_name(job)
        log msg: 'fetching image name',
            job_id: job_id, site: site, infra: infra
        JobBoard::JobQueriesTransformer.new(
          job_data_config: job.fetch('data').fetch('config'), infra: infra
        ).queries.each do |query|
          images = JobBoard::Services::FetchImages.run(query: query.to_hash)
          return images.fetch(0).name unless images.empty?
        end
        'default'
      end

      def cleaned(job)
        job_copy = Marshal.load(Marshal.dump(job))
        data = job_copy.fetch('data', {})
        data.reject! do |k, _|
          %w(
            cache_settings
            env_vars
            source
            ssh_key
          ).include?(k)
        end

        data.fetch('config', {}).reject! do |k, _|
          !%w(
            dist
            group
            language
            os
          ).include?(k)
        end

        data.fetch('job', {}).reject! { |k, _| k != 'id' }
        data.fetch('repository', {}).reject! { |k, _| k != 'slug' }
        job_copy
      end

      def paranoid?(queue)
        config.paranoid_queue_names.include?(queue)
      end

      def config
        JobBoard.config
      end

      def job_id_url(key)
        Addressable::Template.new(
          config.fetch(:"#{key % { site: site }}")
        ).partial_expand('job_id' => job_id).pattern
      end
    end
  end
end
