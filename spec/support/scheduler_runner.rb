# frozen_string_literal: true

require 'fileutils'

module Support
  class SchedulerRunner
    attr_reader :scheduler_thread
    private :scheduler_thread

    def start(port: 9987, count: 3)
      forked_pid_file = pid_file
      JobBoard::Models.db.disconnect
      fork { start_foreground(port: port, count: count, pid: forked_pid_file) }
    end

    def stop
      Process.kill(:TERM, pid) if File.exist?(pid_file)
    ensure
      FileUtils.rm_rf(tmproot)
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
          body = JSON.dump(
            'id' => job_id,
            'data' => {
              'queue' => 'job_board_test'
            }
          )
          command = %(
            curl -fvvSL
              -H 'Content-Type: application/json'
              -H 'Travis-Site: test'
              -d '#{body}'
              http://scheduler:test@127.0.0.1:#{port}/jobs/add
          ).split.join(' ')

          if system(
            command,
            out: stdout_file,
            err: stderr_file,
            unsetenv_others: true
          )
            $stderr.puts "---> added job_id=#{job_id}"
          end
        rescue => e
          $stderr.puts "---> ERROR: #{e}"
        end

        sleep rand(0.001..0.1)
      end
    end

    private def reopen_streams
      FileUtils.mkdir_p(tmproot)
      $stdout = File.open(stdout_file, 'w')
      $stderr = File.open(stderr_file, 'w')
      $stdout.sync = true
      $stderr.sync = true
    end

    private def tmproot
      @tmproot ||= Dir.mktmpdir(%w[job-board- -scheduler-runner])
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
