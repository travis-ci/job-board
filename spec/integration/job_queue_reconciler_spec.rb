# frozen_string_literal: true

describe JobBoard::JobQueueReconciler do
  let :job_queue do
    JobBoard::JobQueue.new(queue_name: queue_name, site: site)
  end
  let(:queue_name) { 'lel' }
  let(:site) { 'test' }

  before do
    keys = %w[sites queues:* queue:*].map do |glob|
      JobBoard.redis.keys(glob)
    end

    JobBoard.redis.multi do |conn|
      keys.flatten.each { |k| conn.del(k) }
    end
  end

  context 'with no data' do
    it 'reconciles' do
      stats = subject.reconcile!
      expect(stats).to_not be_nil
      expect(stats).to_not be_empty
      expect(stats[:sites]).to_not be_nil
      expect(stats[:sites]).to be_empty
    end
  end

  context 'with populated data' do
    before do
      4.times { |n| job_queue.add(job_id: n) }

      job_queue.register(processor: 'a')
      job_queue.register(processor: 'b')
      job_queue.register(processor: 'c')
      job_queue.register(processor: 'd')
      job_queue.register(processor: 'e')
    end

    context 'with all jobs claimed by active processors' do
      before do
        job_queue.claim(processor: 'a')
        job_queue.claim(processor: 'b')
        job_queue.claim(processor: 'c')
        job_queue.claim(processor: 'd')
      end

      xit 'reconciles' do
        stats = subject.reconcile!
        expect(stats).to_not be_nil
        expect(stats).to_not be_empty
        site_def = stats[:sites].find { |s| s[:site] == site.to_sym }
        expect(site_def).to_not be_nil
        expect(site_def).to eq(
          site: site.to_sym,
          processors: [
            {
              name: 'a',
              claimed: 1
            },
            {
              name: 'b',
              claimed: 1
            },
            {
              name: 'c',
              claimed: 1
            },
            {
              name: 'd',
              claimed: 1
            }
          ],
          queues: [
            {
              name: 'lel',
              queued: 0,
              claimed: 4,
              capacity: 5,
              available: 1
            }
          ],
          reclaimed: 0,
          claimed: 4,
          capacity: 5,
          available: 1
        )
        expect(job_queue.claimed?(processor: 'a', job_id: '0')).to be true
        expect(job_queue.claimed?(processor: 'b', job_id: '1')).to be true
        expect(job_queue.claimed?(processor: 'c', job_id: '2')).to be true
        expect(job_queue.claimed?(processor: 'd', job_id: '3')).to be true
      end
    end

    context 'with unclaimed jobs available' do
      before do
        job_queue.claim(processor: 'a')
        job_queue.claim(processor: 'b')
        job_queue.claim(processor: 'c')
      end

      xit 'reconciles' do
        stats = subject.reconcile!
        expect(stats).to_not be_nil
        expect(stats).to_not be_empty
        site_def = stats[:sites].find { |s| s[:site] == site.to_sym }
        expect(site_def).to_not be_nil
        expect(site_def).to eq(
          site: site.to_sym,
          processors: [
            {
              name: 'a',
              claimed: 1
            },
            {
              name: 'b',
              claimed: 1
            },
            {
              name: 'c',
              claimed: 1
            }
          ],
          queues: [
            {
              name: 'lel',
              queued: 1,
              claimed: 3,
              capacity: 5,
              available: 2
            }
          ],
          reclaimed: 0,
          claimed: 3,
          capacity: 5,
          available: 2
        )
        expect(job_queue.claimed?(processor: 'a', job_id: '0')).to be true
        expect(job_queue.claimed?(processor: 'b', job_id: '1')).to be true
        expect(job_queue.claimed?(processor: 'c', job_id: '2')).to be true
      end
    end

    context 'with expired job claims' do
      before do
        job_queue.claim(processor: 'a')
        job_queue.claim(processor: 'b')
        job_queue.claim(processor: 'c')
        job_queue.claim(processor: 'd')
        # NOTE: this `del` command is intended to simulate the expiration of
        # the processor registration.
        JobBoard.redis.del("queues:#{site}:#{queue_name}:processors:a")
      end

      xit 'reconciles' do
        stats = subject.reconcile!
        expect(stats).to_not be_nil
        expect(stats).to_not be_empty
        site_def = stats[:sites].find { |s| s[:site] == site.to_sym }
        expect(site_def).to_not be_nil
        expect(site_def).to eq(
          site: site.to_sym,
          processors: [
            {
              name: 'b',
              claimed: 1
            },
            {
              name: 'c',
              claimed: 1
            },
            {
              name: 'd',
              claimed: 1
            }
          ],
          queues: [
            {
              name: 'lel',
              queued: 1,
              claimed: 3,
              capacity: 4,
              available: 1
            }
          ],
          reclaimed: 1,
          claimed: 3,
          capacity: 4,
          available: 1
        )
        expect(job_queue.claimed?(processor: 'a', job_id: '0')).to be false
        expect(job_queue.claimed?(processor: 'b', job_id: '1')).to be true
        expect(job_queue.claimed?(processor: 'c', job_id: '2')).to be true
        expect(job_queue.claimed?(processor: 'd', job_id: '3')).to be true
      end
    end
  end
end
