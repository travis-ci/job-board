# frozen_string_literal: true
require 'base64'

require 'job_board'
require_relative 'service'

require 'addressable/template'

module JobBoard
  module Services
    class FetchJob < Service
      def initialize(job_id: '', site: '')
        @job_id = job_id.to_s
        @site = site.to_s
      end

      attr_reader :job_id, :site

      def run
        return nil if job_id.empty? || site.empty?

        job_data = {}
        db_job = JobBoard::Models::Job.first(job_id: job_id, site: site)
        return nil unless db_job

        job_data.merge!(db_job.data)
        job_data.merge!(config.build.to_hash)
        # job.merge!(config.cache_options.to_hash) unless
        #   config.cache_options.type.empty?

        job_script_content = fetch_job_script(
          job_data.fetch('id'), job_data.fetch('data')
        )
        return job_script_content if job_script_content.is_a?(
          JobBoard::Services::FetchJobScript::BuildScriptError
        )

        job_data['data'].merge!(
          job_script: {
            name: 'main',
            encoding: 'base64',
            content: Base64.encode64(job_script_content).split.join
          },
          job_state_url: job_id_url('job_state_%{site}_url'),
          log_parts_url: job_id_url('log_parts_%{site}_url'),
          jwt: generate_jwt(job_data.fetch('id')),
          image_name: assign_image_name(job_data)
        )
        job_data
      end

      def fetch_job_script(job_id, job_data_data)
        log msg: 'fetching job script', job_id: job_id, site: site
        JobBoard::Services::FetchJobScript.run(job_data: job_data_data)
      end

      def generate_jwt(job_id)
        log msg: 'creating jwt', job_id: job_id, site: site
        JobBoard::Services::CreateJWT.run(
          job_id: job_id, site: site
        )
      end

      def assign_image_name(_job_data)
        # TODO: implement image name assignment
        'default'
      end

      def config
        JobBoard.config
      end

      def job_id_url(key)
        Addressable::Template.new(
          JobBoard.config.fetch(:"#{key % { site: site }}")
        ).partial_expand('job_id' => job_id).pattern
      end
    end
  end
end
