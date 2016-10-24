# frozen_string_literal: true

describe JobBoard::JobQueue do
  let(:name) { 'lel' }
  let(:site) { 'test' }
  let(:redis) { JobBoard.redis }
  subject { described_class.new(redis: redis, name: name, site: site) }

  context 'with no data' do
    it 'can register' do
      subject.register(worker: 'a')
      expect(redis.exists('sites')).to be true
      expect(redis.exists("queues:#{site}")).to be true
      expect(redis.exists("workers:#{site}")).to be true
    end

    it 'cannot provide job ids for a given worker' do
      expect do
        described_class.for_worker(redis: redis, worker: 'a', site: site)
      end.to raise_error(JobBoard::JobQueue::Invalid)
    end

    it 'cannot provide job ids for a given site' do
      expect do
        described_class.for_site(redis: redis, site: site)
      end.to raise_error(JobBoard::JobQueue::Invalid)
    end

    it 'cannot provide job ids for a given queue' do
      expect do
        described_class.for_queue(redis: redis, site: site, name: name)
      end.to raise_error(JobBoard::JobQueue::Invalid)
    end

    it 'can check claims' do
      claimed = subject.check_claims(worker: 'a', job_ids: %w(0 1 2 3))
      expect(claimed).to be_empty
    end

    it 'can claim a job id' do
      subject.register(worker: 'a')
      claimed = subject.claim(worker: 'a')
      expect(claimed).to be_nil
    end

    it 'can remove a job id' do
      expect(subject.remove(job_id: '0')).to eq(0)
    end

    it 'can add a job id' do
      subject.register(worker: 'a')
      expect(subject.add(job_id: '0')).to eq(1)
    end
  end

  context 'with queued job ids' do
    before :each do
      subject.register(worker: 'a')
      4.times { |n| subject.add(job_id: n.to_s) }
    end

    it 'can provide job ids for a given worker' do
      subject.register(worker: 'a')
      expect(
        described_class.for_worker(redis: redis, worker: 'a', site: site)
      ).to be_empty
    end

    it 'can provide job ids for a given site' do
      subject.register(worker: 'a')
      expect(
        described_class.for_site(redis: redis, site: site)
      ).to eq(
        lel: {
          '0' => { claimed_by: nil },
          '1' => { claimed_by: nil },
          '2' => { claimed_by: nil },
          '3' => { claimed_by: nil }
        }
      )
    end

    it 'can provide job ids for a given queue' do
      subject.register(worker: 'a')
      expect(
        described_class.for_queue(redis: redis, site: site, name: name)
      ).to eq(
        '0' => { claimed_by: nil },
        '1' => { claimed_by: nil },
        '2' => { claimed_by: nil },
        '3' => { claimed_by: nil }
      )
    end

    it 'can register' do
      subject.register(worker: 'a')
      expect(redis.exists('sites')).to be true
      expect(redis.exists("queues:#{site}")).to be true
      expect(redis.exists("workers:#{site}")).to be true
    end

    it 'can check claims' do
      claimed = subject.check_claims(
        worker: 'a', job_ids: %w(0 1 2 3)
      )
      expect(claimed).to eq([])
    end

    it 'can claim a job id' do
      subject.register(worker: 'a')
      claimed = subject.claim(worker: 'a')
      expect(claimed).to_not be_nil
    end

    it 'can remove a job id' do
      expect(subject.remove(job_id: '0')).to eq(1)
    end

    it 'can add a job id' do
      subject.register(worker: 'a')
      expect(subject.add(job_id: '4')).to eq(5)
    end
  end
end
