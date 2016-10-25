# frozen_string_literal: true

describe JobBoard::JobQueueReconciler do
  let :job_queue do
    JobBoard::JobQueue.new(queue_name: queue_name, site: site)
  end
  let(:queue_name) { 'lel' }
  let(:site) { 'test' }

  before do
    keys = %w(sites queues:* queue:* workers:* worker:*).map do |glob|
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

      job_queue.register(worker: 'a')
      job_queue.register(worker: 'b')
      job_queue.register(worker: 'c')
    end

    context 'with all jobs claimed by active workers' do
      before do
        job_queue.claim(worker: 'a')
        job_queue.claim(worker: 'b')
        job_queue.claim(worker: 'a')
        job_queue.claim(worker: 'b')
      end

      it 'reconciles' do
        stats = subject.reconcile!
        expect(stats).to_not be_nil
        expect(stats).to_not be_empty
        expect(stats[:sites][site.to_sym]).to_not be_nil
        expect(stats[:sites][site.to_sym]).to eq(
          workers: {
            'a' => { claimed: 2 },
            'b' => { claimed: 2 },
            'c' => { claimed: 0 }
          },
          queues: {
            'lel' => { queued: 0, claimed: 4 }
          },
          reclaimed: 0
        )
        avail_a = job_queue.check_claims(
          worker: 'a', job_ids: %w(0 2)
        )
        expect(avail_a).to eq(%w(0 2))
        avail_b = job_queue.check_claims(
          worker: 'b', job_ids: %w(1 3)
        )
        expect(avail_b).to eq(%w(1 3))
      end
    end

    context 'with unclaimed jobs available' do
      before do
        job_queue.claim(worker: 'a')
        job_queue.claim(worker: 'b')
        job_queue.claim(worker: 'a')
      end

      it 'reconciles' do
        stats = subject.reconcile!
        expect(stats).to_not be_nil
        expect(stats).to_not be_empty
        expect(stats[:sites][site.to_sym]).to_not be_nil
        expect(stats[:sites][site.to_sym]).to eq(
          workers: {
            'a' => { claimed: 2 },
            'b' => { claimed: 1 },
            'c' => { claimed: 0 }
          },
          queues: {
            'lel' => { queued: 1, claimed: 3 }
          },
          reclaimed: 0
        )
        avail_a = job_queue.check_claims(
          worker: 'a', job_ids: %w(0 2)
        )
        expect(avail_a).to eq(%w(0 2))
        avail_b = job_queue.check_claims(
          worker: 'b', job_ids: %w(1)
        )
        expect(avail_b).to eq(%w(1))
      end
    end

    context 'with expired job claims' do
      before do
        job_queue.claim(worker: 'a')
        job_queue.claim(worker: 'b')
        job_queue.claim(worker: 'a')
        job_queue.claim(worker: 'b')
        # NOTE: these `del` commands are intended to simulate the expiration of
        # the worker queue and index ~meatballhat
        JobBoard.redis.del("worker:#{site}:a:idx")
        JobBoard.redis.del("worker:#{site}:a")
      end

      it 'reconciles' do
        stats = subject.reconcile!
        expect(stats).to_not be_nil
        expect(stats).to_not be_empty
        expect(stats[:sites][site.to_sym]).to_not be_nil
        expect(stats[:sites][site.to_sym]).to eq(
          workers: {
            'a' => { claimed: 0 },
            'b' => { claimed: 2 },
            'c' => { claimed: 0 }
          },
          queues: {
            'lel' => { queued: 2, claimed: 2 }
          },
          reclaimed: 2
        )
        avail_a = job_queue.check_claims(
          worker: 'a', job_ids: %w(0 2)
        )
        expect(avail_a).to eq(%w())
        avail_b = job_queue.check_claims(
          worker: 'b', job_ids: %w(1)
        )
        expect(avail_b).to eq(%w(1))
      end
    end
  end
end
