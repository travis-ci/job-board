# frozen_string_literal: true

require 'support/misc_http_runner'
require 'support/job_board_runner'
require 'support/scheduler_runner'
require 'support/worker_runner'

describe 'Worker Interaction', integration: true do
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

  def job_board_runner_port
    @job_board_runner_port ||= rand(11_000..11_999)
  end

  def misc_http_runner_port
    @misc_http_runner_port ||= job_board_runner_port + 100
  end

  def wait_around(timeout: 60)
    start = Time.now
    loop do
      break if (Time.now - start) > timeout
      begin
        break if yield
      rescue => e
        warn e
      end
      sleep 0.1
    end
  end

  before :all do
    JobBoard::Models::Job.where(site: 'test').delete

    job_board_runner.start(
      port: job_board_runner_port,
      misc_http_port: misc_http_runner_port
    )

    wait_around do
      TCPSocket.new('127.0.0.1', job_board_runner_port)
      true
    end

    misc_http_runner.start(port: misc_http_runner_port)

    wait_around do
      TCPSocket.new('127.0.0.1', misc_http_runner_port)
      true
    end

    worker_runner.start(port: job_board_runner_port)
    scheduler_runner.start(port: job_board_runner_port, count: n_workers * 4)

    wait_around do
      scheduler_runner.scheduled_count > 0
    end

    # TODO: {
    # wait_around do
    #   !JobBoard::JobQueue.for_site(site: 'test')
    #     .fetch(:test, {}).empty?
    # end
    #
    # wait_around do
    #   JobBoard::JobQueue.for_site(site: 'test')
    #     .fetch(:test, {}).empty?
    # end
    # } TODO:
  end

  after :all do
    job_board_runner.stop
    misc_http_runner.stop
    worker_runner.stop
    scheduler_runner.stop
  end

  it 'does stuff' do
    expect(:TODO).to eq :TODO
  end
end
