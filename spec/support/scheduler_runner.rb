# frozen_string_literal: true

require 'fileutils'

module Support
  class SchedulerRunner
    def initialize
      @tmproot = ENV['RSPEC_RUNNER_TMPROOT'] ||
                 Dir.mktmpdir(%w[job-board- -scheduler])
    end

    attr_reader :scheduler_thread, :tmproot
    private :scheduler_thread
    private :tmproot

    def start(port: 9987, count: 3)
      forked_pid_file = pid_file
      JobBoard::Models.db.disconnect
      fork { start_foreground(port: port, count: count, pid: forked_pid_file) }
    end

    def stop
      Process.kill(:TERM, pid) if File.exist?(pid_file)
    ensure
      FileUtils.rm_rf(tmproot) unless ENV.key?('RSPEC_RUNNER_TMPROOT')
    end

    private def start_foreground(port: 9987, count: 3, pid: '',
                                 redir_streams: true)
      reopen_streams if redir_streams
      pid = pid_file if pid.empty?

      $stderr.puts '---> writing pid file'
      File.open(pid, 'w') { |f| f.puts(Process.pid.to_s) }

      $stderr.puts '---> starting scheduler loop'
      scheduler_loop(port: port, count: count)
    end

    private def scheduler_loop(port: 9987, count: 3)
      scheduled = 0
      loop do
        break if scheduled >= count
        scheduled += 1
        File.write(scheduled_count_file, scheduled.to_s)

        job_id = 100_000 + scheduled

        begin
          command = [
            'curl',
            '-fvSL',
            '-H', 'Content-Type: application/json',
            '-H', 'Travis-Site: test',
            '-d', JSON.dump(build_job_body(job_id)),
            "http://scheduler:test@127.0.0.1:#{port}/jobs/add",
            {
              out: stdout_fd.fileno,
              err: stderr_fd.fileno,
              unsetenv_others: true
            }
          ]

          $stderr.puts "---> added job_id=#{job_id}" if system(*command)
        rescue => e
          $stderr.puts "---> ERROR: #{e}"
        end

        sleep rand(0.001..0.1)
      end
    end

    private def build_job_body(job_id)
      {
        'id' => job_id,
        'data' => {
          'queue' => 'test',
          'config' => {
            'language' => 'echo',
            'os' => 'minesweeper'
          }
        }
      }
    end

    private def reopen_streams
      FileUtils.mkdir_p(tmproot)
      $stdout = stdout_fd
      $stderr = stderr_fd
      $stdout.sync = true
      $stderr.sync = true
    end

    private def stdout_fd
      File.open(stdout_file, 'a')
    end

    private def stderr_fd
      File.open(stderr_file, 'a')
    end

    private def pid
      Integer(File.read(pid_file))
    end

    private def pid_file
      File.join(tmproot, 'scheduler.pid')
    end

    private def stdout_file
      File.join(tmproot, 'scheduler.out')
    end

    private def stderr_file
      File.join(tmproot, 'scheduler.err')
    end

    private def scheduled_count_file
      File.join(tmproot, 'scheduled')
    end

    def scheduled_count
      if File.exist?(scheduled_count_file)
        return Integer(File.read(scheduled_count_file))
      end
      0
    end
  end
end
