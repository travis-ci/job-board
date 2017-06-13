# frozen_string_literal: true

require 'support/worker_runner'
require 'support/job_board_runner'
require 'support/scheduler_runner'

describe 'Worker Interaction' do
  def worker_runner
    @worker_runner ||= Support::WorkerRunner.new(n: n_workers)
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
    job_board_runner.start(port: job_board_runner_port)

    wait_around do
      TCPSocket.new('127.0.0.1', job_board_runner_port)
      true
    end

    worker_runner.start(port: job_board_runner_port)
    scheduler_runner.start(port: job_board_runner_port, count: n_workers * 4)

    wait_around do
      scheduler_runner.scheduled_count > 0
    end

    # wait_around do
    #   JobBoard::JobQueue.for_site(site: 'test').empty?
    # end
  end

  after :all do
    job_board_runner.stop
    worker_runner.stop
    scheduler_runner.stop
  end

  before :each do
    allow(JobBoard::Services::FetchJobScript).to receive(:run)
      .and_return(<<~EOF)
        #!/bin/bash
        for thing in a b c d e; do
          echo "doing thing $thing now"
          sleep 1
        done
      EOF

    allow_any_instance_of(JobBoard::Services::FetchJob)
      .to receive(:fetch_image_name)
      .and_return('default')
  end

  it 'does stuff' do
    expect(:wat).to eq :wat
  end
end
