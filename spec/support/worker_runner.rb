# frozen_string_literal: true

require 'fileutils'

module Support
  class WorkerRunner
    def initialize(n: 1, target_version: nil)
      @n = n
      @target_version = target_version ||
                        ENV.fetch('RSPEC_TRAVIS_WORKER_VERSION', 'master')
      @workers = {}
      @tmproot = ENV['RSPEC_RUNNER_TMPROOT'] ||
                 Dir.mktmpdir(%w[job-board- -travis-worker])
    end

    attr_reader :n, :target_version, :tmproot, :workers
    private :n
    private :target_version
    private :tmproot
    private :workers

    def start(port: 9987, maybe_killer: true)
      ensure_worker_exe_exists
      n.times do |worker_n|
        workers[worker_n] = spawn_worker(worker_n, port)
      end
      start_maybe_killer_thread if maybe_killer && n > 1
    end

    def stop
      kill_workers!
      FileUtils.rm_rf(tmproot) unless ENV.key?('RSPEC_RUNNER_TMPROOT')
    end

    def killed_workers
      return [] unless File.exist?(killed_workers_file)
      JSON.parse(File.read(killed_workers_file))
    end

    private def kill_workers!
      workers.keys.each do |worker_n|
        worker = workers[worker_n]
        Process.kill(:TERM, worker[:pid])
        workers.delete(worker_n)
      end
    end

    private def spawn_worker(worker_n, port)
      pid = spawn(
        build_worker_env(worker_n, port),
        worker_exe,
        %i[out err] => [build_worker_log_output(worker_n), 'w']
      )
      workers[worker_n] = { pid: pid }
    end

    private def start_maybe_killer_thread(initial_sleep: 5)
      sleep initial_sleep
      to_kill = {}
      (workers.size * 0.25).ceil.times do |_n|
        to_kill[workers.values.sample.fetch(:pid)] = true
      end

      Thread.start do
        loop do
          break if to_kill.empty?
          pid = to_kill.keys.first
          Process.kill(:TERM, pid)
          to_kill.delete(pid)
          save_killed_worker(pid)
          sleep rand(1..10)
        end
      end
    end

    private def ensure_worker_exe_exists
      return if File.exist?(worker_exe)
      FileUtils.mkdir_p(File.dirname(worker_exe))

      dl_out_file = File.join(tmproot, 'worker-download.out')
      unless system(
        'curl',
        '-o', worker_exe,
        '-vvfSL',
        worker_download_url,
        %i[out err] => dl_out_file
      )
        raise StandardError, 'Failed to download worker from ' \
                             "#{worker_download_url.inspect}: " \
                             "#{File.read(dl_out_file)}"
      end

      FileUtils.chmod(0o755, worker_exe)
    end

    private def build_worker_env(worker_n, port)
      worker_scripts_dir = File.join(
        scripts_dir, "worker.#{worker_n}"
      )
      FileUtils.mkdir_p(worker_scripts_dir)

      job_board_url = "http://worker#{worker_n}:test@127.0.0.1:#{port}"
      worker_pool_size = ENV.fetch('RSPEC_TRAVIS_WORKER_POOL_SIZE', '3')

      {
        'TRAVIS_WORKER_DEBUG' => 'true',
        'TRAVIS_WORKER_JOB_BOARD_URL' => job_board_url,
        'TRAVIS_WORKER_LOCAL_SCRIPTS_DIR' => worker_scripts_dir,
        'TRAVIS_WORKER_POOL_SIZE' => worker_pool_size,
        'TRAVIS_WORKER_PROVIDER_NAME' => 'local',
        'TRAVIS_WORKER_QUEUE_NAME' => 'test',
        'TRAVIS_WORKER_QUEUE_TYPE' => 'http',
        'TRAVIS_WORKER_SILENCE_METRICS' => 'true',
        'TRAVIS_WORKER_TRAVIS_SITE' => 'test'
      }
    end

    private def build_worker_log_output(worker_n)
      File.join(tmproot, "worker.#{worker_n}.out")
    end

    private def worker_exe
      @worker_exe ||= File.expand_path('../bin/travis-worker', __FILE__)
    end

    private def worker_download_url
      @worker_download_url ||= File.join(
        'https://s3.amazonaws.com',
        'travis-worker-artifacts',
        'travis-ci',
        'worker',
        target_version,
        target_platform,
        'amd64',
        'travis-worker'
      )
    end

    private def save_killed_worker(pid)
      current = killed_workers
      current << Integer(pid)
      File.write(killed_workers_file, JSON.dump(current))
    end

    private def killed_workers_file
      File.join(tmproot, 'killed-workers.json')
    end

    private def scripts_dir
      @scripts_dir ||= File.join(tmproot, 'scripts')
    end

    private def target_platform
      @target_platform ||= begin
        case RUBY_PLATFORM
        when /linux/i then 'linux'
        when /darwin/i then 'darwin'
        else
          raise StandardError, "unsupported/unknown platform #{RUBY_PLATFORM}"
        end
      end
    end
  end
end
