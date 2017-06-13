# frozen_string_literal: true

require 'fileutils'

require 'rack/server'
require 'sinatra/base'

module Support
  class MiscHttpApp < Sinatra::Base
    configure do
      enable :logging
    end

    post '/log-parts/multi' do
      $stderr.puts '---> POST /log-parts/multi ' \
                   "body: #{request.body.read}"
      status 200
    end

    patch '/jobs/:job_id/state' do
      $stderr.puts "---> PATCH /jobs/#{params[:job_id]}/state " \
                   "body: #{request.body.read}"
      status 200
    end

    post '/script' do
      $stderr.puts "---> POST /script body: #{request.body.read}"
      status 200
      content_type :text
      body gen_script
    end

    private def gen_script
      <<~EOF
        #!/bin/bash
        for thing in a b c d e; do
          echo "doing thing $thing now"
          sleep 1
        done
      EOF
    end
  end

  class MiscHttpRunner
    def initialize
      @tmproot = ENV['RSPEC_RUNNER_TMPROOT'] ||
                 Dir.mktmpdir(%w[job-board- -job-board])
    end

    attr_reader :tmproot
    private :tmproot

    def start(port: 10_087)
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

    private def start_rack_server(options: {})
      reopen_streams
      $stderr.puts '---> starting misc http server'
      Rack::Server.start(options)
    end

    private def reopen_streams
      $stdout = File.open(stdout_file, 'a')
      $stderr = File.open(stderr_file, 'a')
      $stdout.sync = true
      $stderr.sync = true
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
