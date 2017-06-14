# frozen_string_literal: true

require 'support/misc_http_runner'
require 'support/job_board_runner'
require 'support/scheduler_runner'
require 'support/worker_runner'

describe 'Worker Interaction', integration: true do
  def suite_start
    @suite_start ||= Time.now.utc
  end

  def worker_runner
    @worker_runner ||= Support::WorkerRunner.new(n: n_workers)
  end

  def misc_http_runner
    @misc_http_runner ||= Support::MiscHttpRunner.new
  end

  def job_board_runner
    @job_board_runner ||= Support::JobBoardRunner.new
  end

  def scheduler_runner
    @scheduler_runner ||= Support::SchedulerRunner.new
  end

  def n_workers
    @n_workers ||= rand(10..29)
  end

  def job_count
    n_workers * 4
  end

  def job_board_runner_port
    @job_board_runner_port ||= rand(11_000..11_999)
  end

  def misc_http_runner_port
    @misc_http_runner_port ||= job_board_runner_port + 100
  end

  def travis?
    !ENV['TRAVIS'].to_s.empty?
  end

  def wait_around(label: '???', timeout: 60, loop_sleep: 0.1)
    $stderr.print("Worker Interaction: waiting for #{label}") if travis?
    start = Time.now
    loop do
      break if (Time.now - start) > timeout
      begin
        break if yield
      rescue => e
        warn e
      end
      $stderr.print('.') if travis?
      sleep loop_sleep
    end
    $stderr.puts('') if travis?
  end

  before :all do
    expect(suite_start).to_not be_nil

    JobBoard::Models::Job.where(site: 'test').delete

    job_board_runner.start(
      port: job_board_runner_port,
      misc_http_port: misc_http_runner_port
    )

    wait_around(label: 'job-board availability') do
      TCPSocket.new('127.0.0.1', job_board_runner_port)
      true
    end

    misc_http_runner.start(port: misc_http_runner_port)

    wait_around(label: 'misc http stuff availability') do
      TCPSocket.new('127.0.0.1', misc_http_runner_port)
      true
    end

    worker_runner.start(port: job_board_runner_port)
    scheduler_runner.start(port: job_board_runner_port, count: job_count)

    wait_around(label: 'first scheduled job') do
      scheduler_runner.scheduled_count > 0
    end

    wait_around(label: 'first queued job', loop_sleep: 1) do
      !JobBoard::JobQueue.for_site(site: 'test')
                         .fetch(:test, {}).empty?
    end

    wait_around(label: 'emptied queue', loop_sleep: 10) do
      JobBoard::JobQueue.for_site(site: 'test')
                        .fetch(:test, {}).empty?
    end

    wait_around(label: 'finished jobs', loop_sleep: 1) do
      JobBoard::Models::Job.where(site: 'test').count.zero?
    end
  end

  after :all do
    job_board_runner.stop
    misc_http_runner.stop
    worker_runner.stop
    scheduler_runner.stop
  end

  it 'schedules jobs' do
    expect(scheduler_runner.scheduled_summary).to_not be_empty
  end

  it 'schedules each job only once' do
    expect(scheduler_runner.scheduled_summary.length)
      .to eq scheduler_runner.scheduled_summary.sort.uniq.length
  end

  it 'schedules the correct job count' do
    expect(scheduler_runner.scheduled_summary.sort.uniq.length).to eq job_count
  end

  it 'removes all records of completed jobs' do
    expect(JobBoard::Models::Job.where(site: 'test').count).to be_zero
  end

  it 'marks jobs completed only when completed' do
    finished_files = Dir["#{misc_http_runner.tmproot}/job-*-finished"]
    expect(finished_files.length).to eq job_count

    finished_timestamps = finished_files.map { |fn| Integer(File.read(fn)) }
    finished_timestamps.sort!

    expect(finished_timestamps.min).to be > suite_start.to_i
    expect(finished_timestamps.max).to be < Time.now.utc.to_i
  end
end
