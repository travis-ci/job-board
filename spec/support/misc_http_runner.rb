# frozen_string_literal: true

require 'fileutils'
require 'rack'
require 'sinatra/base'

module Support
  class MiscHttpApp < Sinatra::Base
    class << self
      attr_accessor :state_summary_file

      def state_summary_mutex
        @state_summary_mutex ||= Mutex.new
      end
    end

    configure do
      enable :logging
    end

    post '/log-parts/multi' do
      warn '---> POST /log-parts/multi ' \
                   "body: #{request.body.read}"
      status 204
    end

    patch '/jobs/:job_id/state' do
      parsed = JSON.parse(request.body.read)
      warn "---> PATCH /jobs/#{params[:job_id]}/state body: #{parsed}"
      save_state_update(params[:job_id], parsed)
      status 200
    end

    post '/script' do
      request_body = request.body.read
      request_json = JSON.parse(request_body)
      warn "---> POST /script body: #{request_body}"
      status 200
      content_type :text
      body gen_script(
        request_json.fetch('job', {}).fetch('id', '???'),
        Digest::SHA1.hexdigest(request_body)
      )
    end

    private def gen_script(job_id, sig)
      <<~EOF
        #!/bin/bash
        # job_id: #{job_id}
        # config signature: #{sig}

        for thing in a b c d e; do
          echo "doing thing $thing now"
          sleep 1
        done
      EOF
    end

    private def save_state_update(job_id, data)
      fname = self.class.state_summary_file

      self.class.state_summary_mutex.synchronize do
        current = []
        current += JSON.parse(File.read(fname)) if File.exist?(fname)
        current << { 'job_id' => job_id, 'data' => data }
        File.write(fname, JSON.pretty_generate(current))
      end
    end
  end

  class MiscHttpRunner
    def initialize
      @tmproot = ENV['RSPEC_RUNNER_TMPROOT'] ||
                 Dir.mktmpdir(%w[job-board- -job-board])
    end

    attr_reader :tmproot

    def start(port: 10_087)
      Support::MiscHttpApp.state_summary_file = state_summary_file
      File.write(state_summary_file, '[]')

      @options = {
        Port: port,
        app: Support::MiscHttpApp,
        daemonize: true,
        pid: server_pid_file
      }

      fork { start_rack_server(options: @options) }
      server_pid if File.exist?(server_pid_file)
    end

    def stop
      Process.kill(:INT, server_pid)
    ensure
      FileUtils.rm_rf(tmproot) unless ENV.key?('RSPEC_RUNNER_TMPROOT')
    end

    def state_summary
      return [] unless File.exist?(state_summary_file)

      JSON.parse(File.read(state_summary_file))
    end

    private def start_rack_server(options: {})
      reopen_streams
      warn '---> starting misc http server'
      Rack::Server.start(options)
    end

    private def reopen_streams
      $stdout = File.open(stdout_file, 'a')
      $stderr = File.open(stderr_file, 'a')
      $stdout.sync = true
      $stderr.sync = true
    end

    private def state_summary_file
      File.join(tmproot, 'state-summary.json')
    end

    private def stdout_file
      File.join(tmproot, 'misc-rack-server.out')
    end

    private def stderr_file
      File.join(tmproot, 'misc-rack-server.err')
    end

    private def server_pid_file
      File.join(tmproot, 'misc-rack-server.pid')
    end

    private def server_pid
      @server_pid ||= Integer(File.read(server_pid_file))
    end
  end
end
