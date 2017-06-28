# frozen_string_literal: true

describe JobBoard::Services::FetchJob do
  subject { described_class.new(job_id: job_id, site: site) }
  let(:job_id) { (Time.now.to_i + rand(100..199)).to_s }
  let(:site) { 'test' }
  let(:queue) { 'lel' }
  let(:paranoid) { false }
  let(:fake_db_job) { double('job') }
  let :data do
    {
      '@type' => 'job',
      'id' => job_id,
      'queue' => queue,
      'data' => {
        'config' => {
          'language' => 'rubby',
          'os' => 'lannix'
        }
      }
    }
  end

  let :job_script_data do
    {
      'config' => {
        'language' => 'rubby',
        'os' => 'lannix'
      },
      'paranoid' => paranoid
    }.merge(config.fetch(:build))
  end

  let :config do
    JobBoard::Config.new(
      build: {
        fix_resolv_conf: :sure,
        fix_etc_hosts: :sure,
        hosts: {
          apt_cache: 'http://falafel.example.com',
          npm_cache: 'http://waffle.example.com'
        }
      },
      job_state_test_url: 'http://flah.example.com',
      log_parts_test_url: 'http://floo.example.com',
      paranoid_queues: 'lol,nah'
    )
  end

  before do
    allow(JobBoard::Models::Job).to receive(:first)
      .with(job_id: job_id, site: site)
      .and_return(fake_db_job)
    allow(JobBoard::Services::FetchJobScript).to receive(:run)
      .with(job_data: job_script_data, site: site)
      .and_return("#!/bin/bash\necho wat\n")
    allow(JobBoard::Services::CreateJWT).to receive(:run)
      .with(job_id: job_id, site: site)
      .and_return('FAFAFAF.ABABABA.DADADAD')
    allow(subject).to receive(:config).and_return(config)
    allow(fake_db_job).to receive(:data).and_return(data)
    allow(fake_db_job).to receive(:queue).and_return(queue)
  end

  it 'fetches a job' do
    expect(subject.run).to_not be_nil
  end

  context 'when the queue is in the paranoid queues list' do
    let(:queue) { 'nah' }
    let(:paranoid) { true }

    it 'fetches a job' do
      expect(subject.run).to_not be_nil
    end
  end
end
