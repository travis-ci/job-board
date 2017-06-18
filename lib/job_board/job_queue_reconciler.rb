# frozen_string_literal: true

require 'job_board'

module JobBoard
  class JobQueueReconciler
    def initialize(redis: nil)
      @redis = redis || JobBoard.redis
    end

    attr_reader :redis

    def reconcile!(with_ids: JobBoard.config.reconcile_stats_with_ids)
      JobBoard.logger.info('starting reconciliation process')
      start_time = Time.now
      stats = { sites: {} }

      redis.smembers('sites').map(&:to_sym).each do |site|
        next if site.to_s.empty?

        stats[:sites][site] = {
          workers: {},
          queues: {}
        }

        JobBoard.logger.info('reconciling', site: site)
        reclaimed, claimed = reconcile_site!(site: site)

        JobBoard.logger.info('reclaimed jobs', site: site, n: reclaimed.length)
        stats[:sites][site][:reclaimed] = reclaimed.length
        stats[:sites][site][:reclaimed_ids] = reclaimed if with_ids
        stats[:sites][site][:workers].merge!(claimed)

        JobBoard.logger.info('fetching queue stats', site: site)
        stats[:sites][site][:queues].merge!(measure(site))
      end

      JobBoard.logger.info('finished with reconciliation process')
      stats.merge(time: "#{Time.now - start_time}s")
    end

    private def reconcile_site!(site: '')
      reclaimed = []
      claimed = {}

      redis.smembers("workers:#{site}").each do |worker|
        worker = worker.to_s.strip
        next if worker.empty?

        if worker_is_current?(site: site, worker: worker)
          claimed[worker] = {
            claimed: redis.llen("worker:#{site}:#{worker}")
          }
        else
          reclaimed += reclaim_jobs_from_worker(site: site, worker: worker)
          claimed[worker] = { claimed: 0 }
        end
      end

      [reclaimed, claimed]
    end

    private def worker_is_current?(site: '', worker: '')
      redis.exists("worker:#{site}:#{worker}")
    end

    private def reclaim_jobs_from_worker(site: '', worker: '')
      reclaimed = []

      redis.smembers("queues:#{site}").each do |queue_name|
        reclaimed += reclaim!(
          worker: worker, site: site, queue_name: queue_name
        )
      end

      reclaimed
    end

    private def reclaim!(worker: '', site: '', queue_name: '')
      reclaimed = []
      return reclaimed if worker.empty? || site.empty? || queue_name.empty?

      claims = redis.hgetall("queue:#{site}:#{queue_name}:claims")
      claims.each do |job_id, claimer|
        next unless worker == claimer
        reclaim_job(
          worker: worker, job_id: job_id, site: site, queue_name: queue_name
        )
        reclaimed << job_id
      end

      reclaimed
    end

    private def measure(site)
      measured = {}

      redis.smembers("queues:#{site}").each do |queue_name|
        resp = redis.multi do |conn|
          conn.llen("queue:#{site}:#{queue_name}")
          conn.hlen("queue:#{site}:#{queue_name}:claims")
        end

        measured[queue_name] = {
          queued: resp.fetch(0),
          claimed: resp.fetch(1)
        }
      end

      measured
    end

    private def reclaim_job(worker: '', job_id: '', site: '', queue_name: '')
      redis.multi do |conn|
        conn.srem("worker:#{site}:#{worker}:idx", job_id)
        conn.lrem("worker:#{site}:#{worker}", 1, job_id)
        conn.rpush("queue:#{site}:#{queue_name}", job_id)
        conn.hdel("queue:#{site}:#{queue_name}:claims", job_id)
        conn.hdel("queue:#{site}:#{queue_name}:claims:timestamps", job_id)
      end
    end
  end
end
