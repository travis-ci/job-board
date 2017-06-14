# frozen_string_literal: true

require 'fileutils'

module Support
  class WorkerRunner
    def initialize(n: 1, target_version: 'v2.9.1', kill_tendency: 29)
      @n = n
      @target_version = target_version
      @kill_tendency = kill_tendency
      @workers = {}
      @tmproot = ENV['RSPEC_RUNNER_TMPROOT'] ||
                 Dir.mktmpdir(%w[job-board- -travis-worker])
    end

    attr_reader :kill_tendency, :n, :target_version, :tmproot, :workers
    private :kill_tendency
    private :n
    private :target_version
    private :tmproot
    private :workers

    def start(port: 9987)
      ensure_worker_exe_exists
      n.times do |worker_n|
        workers[worker_n] = spawn_worker(worker_n, port)
      end
      start_maybe_killer_thread
    end

    def stop
      kill_workers!
      FileUtils.rm_rf(tmproot) unless ENV.key?('RSPEC_RUNNER_TMPROOT')
    end

    private def kill_workers!(maybe: false, sig: :TERM)
      return if maybe && !(Time.now.to_i % kill_tendency).zero?
      return if maybe && workers.length == 1

      workers.keys.each do |worker_n|
        worker = workers[worker_n]
        Process.kill(sig, worker[:pid])
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

    private def start_maybe_killer_thread
      Thread.start do
        loop do
          kill_workers!(maybe: true, sig: :INT)
          sleep rand(1..10)
        end
      end
    end

    private def ensure_worker_exe_exists
      return if File.exist?(worker_exe)

      unless system('curl', '-o', worker_exe, '-sfSL', worker_download_url)
        raise StandardError, 'Failed to download worker from ' \
                             "#{worker_download_url.inspect}"
      end

      FileUtils.chmod(0o755, worker_exe)
    end

    private def build_worker_env(worker_n, port)
      worker_scripts_dir = File.join(
        scripts_dir, "worker.#{worker_n}"
      )
      FileUtils.mkdir_p(worker_scripts_dir)

      job_board_url = "http://worker#{worker_n}:test@127.0.0.1:#{port}"

      {
        'TRAVIS_WORKER_DEBUG' => 'true',
        'TRAVIS_WORKER_JOB_BOARD_URL' => job_board_url,
        'TRAVIS_WORKER_LOCAL_SCRIPTS_DIR' => worker_scripts_dir,
        'TRAVIS_WORKER_POOL_SIZE' => '3',
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
