# frozen_string_literal: true

require 'fileutils'
require 'logger'

module Support
  class JobBoardReconcilerRunner
    def initialize
      @tmproot = ENV['RSPEC_RUNNER_TMPROOT'] ||
                 Dir.mktmpdir(%w[job-board- -job-board-reconciler])
    end

    attr_reader :tmproot
    private :tmproot

    def start
      JobBoard::Models.db.disconnect
      fork { start_reconciler }
      pid if File.exist?(pid_file)
    end

    def stop
      Process.kill(:KILL, pid) if File.exist?(pid_file)
    ensure
      FileUtils.rm_f(pid_file)
      FileUtils.rm_rf(tmproot) unless ENV.key?('RSPEC_RUNNER_TMPROOT')
    end

    private def start_reconciler
      reopen_streams

      JobBoard.config.reconcile_stats_with_ids = true
      JobBoard.instance_variable_set(:@logger, nil)
      JobBoard.logdev = $stdout
      JobBoard.logger.level = ::Logger::DEBUG

      File.write(pid_file, Process.pid.to_s)

      load File.expand_path('../../../bin/job-board-reconcile-jobs', __FILE__)
    end

    private def reopen_streams
      $stdout = File.open(stdout_file, 'a')
      $stderr = File.open(stderr_file, 'a')
      $stdout.sync = true
      $stderr.sync = true
    end

    private def stdout_file
      File.join(tmproot, 'reconciler.out')
    end

    private def stderr_file
      File.join(tmproot, 'reconciler.err')
    end

    private def pid_file
      File.join(tmproot, 'reconciler.pid')
    end

    private def pid
      @pid ||= Integer(File.read(pid_file))
    end
  end
end
