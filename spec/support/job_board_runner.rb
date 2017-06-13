# frozen_string_literal: true

require 'fileutils'
require 'rack/server'

require 'job_board'

module Support
  class JobBoardRunner
    def start(port: 9987)
      @options = {
        Port: port,
        Server: 'webrick',
        app: JobBoard::App,
        daemonize: true,
        pid: server_pid_file
      }

      JobBoard::Models.db.disconnect
      fork { start_rack_server(options: @options) }
      server_pid if File.exist?(server_pid_file)
    end

    def stop
      Process.kill(:INT, server_pid)
    ensure
      FileUtils.rm_rf(tmproot)
    end

    private def start_rack_server(options: {})
      reopen_streams
      $stderr.puts '---> starting server'
      Rack::Server.start(options)
    end

    private def tmproot
      @tmproot ||= Dir.mktmpdir(%w[job-board- -runner])
    end

    private def reopen_streams
      $stdout = File.open(stdout_file, 'w')
      $stderr = File.open(stderr_file, 'w')
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
