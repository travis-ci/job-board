# frozen_string_literal: true
require 'base64'
require 'job_board'

module JobBoard
  module Services
    class FetchJob
      def self.run(job_id: '')
        new(job_id: job_id).run
      end

      attr_reader :job_id

      def initialize(job_id: '')
        @job_id = job_id
      end

      def run
        job = {}
        db_job = JobBoard::Models::Job.first(job_id: job_id)
        return nil unless db_job
        job.merge!(db_job.data)
        job['build_scripts'] = [
          {
            name: 'main',
            encoding: 'base64',
            content: Base64.encode64(fetch_job_script(job)).split.join
          }
        ]
        job['job_state_url'] = JobBoard.config.job_state_url
        job['log_parts_url'] = JobBoard.config.log_parts_url
        job['jwt'] = generate_jwt
        job
      end

      def fetch_job_script(job)
        JobBoard::Services::FetchJobScript.run(job: job)
      end

      def generate_jwt
        # TODO: implement jwt generation
        'FAFAFAF.ABABABA.DADADAD'
      end
    end
  end
end
