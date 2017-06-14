# frozen_string_literal: true

require 'fileutils'

require 'addressable/uri'
require 'l2met-log'
require 'rack/server'

require 'job_board'

module Support
  class JobBoardRunner
    def initialize
      @tmproot = ENV['RSPEC_RUNNER_TMPROOT'] ||
                 Dir.mktmpdir(%w[job-board- -job-board])
    end

    attr_reader :tmproot
    private :tmproot

    def start(port: 9987, misc_http_port: 10_087)
      @options = {
        Port: port,
        app: JobBoard::App,
        daemonize: true,
        pid: server_pid_file
      }

      JobBoard::Models.db.disconnect
      fork do
        start_rack_server(
          options: @options, misc_http_port: misc_http_port
        )
      end
      server_pid if File.exist?(server_pid_file)
    end

    def stop
      Process.kill(:INT, server_pid)
    ensure
      FileUtils.rm_rf(tmproot) unless ENV.key?('RSPEC_RUNNER_TMPROOT')
    end

    private def start_rack_server(options: {}, misc_http_port: 10_087)
      reopen_streams
      $stderr.puts '---> starting server'

      L2met::Log.default_log_level = :debug

      misc_base_url = "http://127.0.0.1:#{misc_http_port}"
      JobBoard.config[:job_state_test_url] = File.join(
        misc_base_url,
        'jobs/{job_id}/state'
      )
      JobBoard.config[:log_parts_test_url] = File.join(
        misc_base_url,
        'log-parts/multi'
      )

      JobBoard::Services::FetchJobScript.build_uri =
        Addressable::URI.parse(misc_base_url)

      Rack::Server.start(options)
    end

    private def reopen_streams
      $stdout = File.open(stdout_file, 'a')
      $stderr = File.open(stderr_file, 'a')
      $stdout.sync = true
      $stderr.sync = true
    end

    private def stdout_file
      File.join(tmproot, 'rack-server.out')
    end

    private def stderr_file
      File.join(tmproot, 'rack-server.err')
    end

    private def server_pid_file
      File.join(tmproot, 'rack-server.pid')
    end

    private def server_pid
      @server_pid ||= Integer(File.read(server_pid_file))
    end
  end
end
