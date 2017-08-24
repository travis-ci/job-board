# frozen_string_literal: true

describe JobBoard::JobQueue do
  let(:queue_name) { 'lel' }
  let(:site) { 'test' }
  let(:redis_pool) { JobBoard.redis_pool }
  let(:redis) { JobBoard.redis }

  subject do
    described_class.new(
      redis_pool: redis_pool, queue_name: queue_name, site: site
    )
  end

  before :each do
    redis.multi do |conn|
      %W[
        queue:#{site}:#{queue_name}
        queue:#{site}:#{queue_name}:claims
        queue:#{site}:#{queue_name}:claims:timestamps
        queue:#{site}:#{queue_name}:processors:a
        queues:#{site}
      ].each do |key|
        conn.del(key)
      end
      conn.srem('sites', site)
    end
  end

  context 'with no data' do
    it 'can register' do
      subject.register(processor: 'a')
      expect(redis.exists('sites')).to be true
      expect(redis.exists("queues:#{site}")).to be true
      expect(redis.exists("queues:#{site}:#{queue_name}:processor:a"))
        .to be true
    end

    it 'cannot provide job id for a given processor' do
      expect do
        described_class.for_processor(redis: redis, processor: 'a', site: site)
      end.to raise_error(JobBoard::JobQueue::Invalid)
    end

    it 'cannot provide job ids for a given site' do
      expect do
        described_class.for_site(redis: redis, site: site)
      end.to raise_error(JobBoard::JobQueue::Invalid)
    end

    it 'cannot provide job ids for a given queue' do
      expect do
        described_class.for_queue(
          redis: redis, site: site, queue_name: queue_name
        )
      end.to raise_error(JobBoard::JobQueue::Invalid)
    end

    it 'can check claims' do
      expect(subject.claimed?(processor: 'a', job_id: '0')).to be false
    end

    it 'can claim a job id' do
      subject.register(processor: 'a')
      claimed = subject.claim(processor: 'a')
      expect(claimed).to be_nil
    end

    it 'can remove a job id' do
      expect(subject.remove(job_id: '0')).to eq(0)
    end

    it 'can add a job id' do
      subject.register(processor: 'a')
      expect(subject.add(job_id: '0').last).to eq(1)
    end
  end

  context 'with queued job ids' do
    before :each do
      subject.register(processor: 'a')
      4.times { |n| subject.add(job_id: n.to_s) }
    end

    it 'can provide job ids for a given processor' do
      subject.register(processor: 'a')
      expect(
        described_class.for_processor(
          redis: redis, processor: 'a', site: site, queue_name: queue_name
        )
      ).to be_empty
    end

    it 'can provide job ids for a given site' do
      subject.register(processor: 'a')
      expect(
        described_class.for_site(redis: redis, site: site)
      ).to eq(
        [
          {
            queue: :lel,
            jobs: [
              { id: '3', claimed_by: nil },
              { id: '2', claimed_by: nil },
              { id: '1', claimed_by: nil },
              { id: '0', claimed_by: nil }
            ]
          }
        ]
      )
    end

    it 'can provide job ids for a given queue' do
      subject.register(processor: 'a')
      expect(
        described_class.for_queue(
          redis: redis, site: site, queue_name: queue_name
        )
      ).to eq(
        [
          { id: '3', claimed_by: nil },
          { id: '2', claimed_by: nil },
          { id: '1', claimed_by: nil },
          { id: '0', claimed_by: nil }
        ]
      )
    end

    it 'can register' do
      subject.register(processor: 'a')
      expect(redis.exists('sites')).to be true
      expect(redis.exists("queues:#{site}")).to be true
      expect(redis.exists("queues:#{site}:#{queue_name}:processor:a"))
        .to be true
    end

    it 'can check claims' do
      expect(subject.claimed?(processor: 'a', job_id: '0')).to be false
    end

    it 'can claim a job id' do
      subject.register(processor: 'a')
      expect(subject.claim(processor: 'a')).to_not be_nil
    end

    it 'can remove a job id' do
      expect(subject.remove(job_id: '0')).to eq(1)
    end

    it 'can add a job id' do
      subject.register(processor: 'a')
      expect(subject.add(job_id: '4').last).to eq(5)
    end
  end
end
