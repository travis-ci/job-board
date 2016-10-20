# frozen_string_literal: true
require_relative 'service'

module JobBoard
  module Services
    class FetchQueue < Service
      def initialize(job: {})
        @job = job
      end

      attr_reader :job

      def run
        # TODO: implement proper queue selection via databass
        send("select_os_#{job.fetch('os', 'linux')}")
      rescue
        'gce'
      end

      def select_os_linux
        send("select_linux_sudo_#{job.fetch('sudo', 'false')}")
      end

      def select_linux_sudo_false
        'ec2'
      end

      def select_linux_sudo_required
        'gce'
      end

      def select_os_osx
        'macstadium6'
      end
    end
  end
end
