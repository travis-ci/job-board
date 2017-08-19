# frozen_string_literal: true

require 'job_board'

module JobBoard
  class JobQueueReconciler
    def initialize(redis_pool: nil, job_model: nil)
      @redis_pool = redis_pool || JobBoard.redis_pool
      @job_model = job_model || JobBoard::Models::Job
    end

    attr_reader :redis_pool, :job_model

    def reconcile!(with_ids: JobBoard.config.reconcile_stats_with_ids,
                   purge_unknown: false)
      JobBoard.logger.info('starting reconciliation process')
      start_time = Time.now
      stats = { sites: [] }

      redis_pool.with do |redis|
        redis.smembers('sites').sort.map(&:to_sym).each do |site|
          next if site.to_s.empty?

          if purge_unknown
            JobBoard.logger.info('purging unknown jobs', site: site)
            purge_unknown_jobs!(redis: redis, site: site)
          end

          site_def = {
            site: site.to_sym,
            workers: [],
            queues: []
          }

          JobBoard.logger.info('reconciling', site: site)
          reclaimed, claimed = reconcile_site!(redis: redis, site: site)

          total_capacity = measure_capacity(redis: redis, site: site)
          total_claimed = claimed.values.select(&:positive?).reduce(:+) || 0
          site_def.merge!(
            capacity: total_capacity,
            claimed: total_claimed,
            available: total_capacity - total_claimed
          )

          JobBoard.logger.info('reclaimed jobs', site: site, n: reclaimed.length)
          site_def[:reclaimed] = reclaimed.length
          site_def[:reclaimed_ids] = reclaimed if with_ids

          claimed.each do |worker_name, count|
            site_def[:workers] << {
              name: worker_name,
              claimed: count
            }
          end

          JobBoard.logger.info('fetching queue stats', site: site)
          site_def[:queues] = measure_queues(redis: redis, site: site)

          stats[:sites] << site_def
        end

        JobBoard.logger.info('finished with reconciliation process')
        stats.merge(time: "#{Time.now - start_time}s")
      end
    end

    private def reconcile_site!(redis: nil, site: '')
      reclaimed = []
      claimed = {}

      redis.smembers("workers:#{site}").sort.each do |worker|
        worker = worker.to_s.strip
        next if worker.empty?

        if worker_is_current?(redis: redis, site: site, worker: worker)
          claimed[worker] = redis.llen("worker:#{site}:#{worker}")
        else
          reclaimed += reclaim_jobs_from_worker(
            redis: redis, site: site, worker: worker
          )
          redis.srem("workers:#{site}", worker)
        end
      end

      [reclaimed, claimed]
    end

    private def measure_capacity(redis: nil, site: '')
      total = 0
      redis.scan_each(match: "worker:#{site}:*:capacity") do |key|
        redis.hvals(key).each do |i|
          total += Integer(i) unless i.nil? || i.empty?
        end
      end
      total
    end

    private def worker_is_current?(redis: nil, site: '', worker: '')
      redis.exists("worker:#{site}:#{worker}:capacity")
    end

    private def reclaim_jobs_from_worker(redis: nil, site: '', worker: '')
      reclaimed = []

      redis.smembers("queues:#{site}").sort.each do |queue_name|
        reclaimed += reclaim!(
          redis: redis, worker: worker, site: site, queue_name: queue_name
        )
      end

      reclaimed
    end

    private def reclaim!(redis: nil, worker: '', site: '', queue_name: '')
      reclaimed = []
      return reclaimed if worker.empty? || site.empty? || queue_name.empty?

      claims = redis.hgetall("queue:#{site}:#{queue_name}:claims")
      claims.each do |job_id, claimer|
        next unless worker == claimer
        reclaim_job(
          redis: redis, worker: worker, job_id: job_id,
          site: site, queue_name: queue_name
        )
        reclaimed << job_id
      end

      reclaimed
    end

    private def measure_queues(redis: nil, site: '')
      measured = []

      redis.smembers("queues:#{site}").sort.each do |queue_name|
        resp = redis.multi do |conn|
          conn.llen("queue:#{site}:#{queue_name}")
          conn.hlen("queue:#{site}:#{queue_name}:claims")
        end

        queue_def = {
          name: queue_name,
          queued: resp.fetch(0),
          claimed: resp.fetch(1)
        }

        queue_capacity = 0

        redis.scan_each(match: "worker:#{site}:*:capacity") do |key|
          cap = redis.hget(key, queue_name)
          queue_capacity += Integer(cap) unless cap.nil? || cap.empty?
        end

        measured << queue_def.merge(
          capacity: queue_capacity,
          available: queue_capacity - queue_def[:claimed]
        )
      end

      measured
    end

    private def reclaim_job(
      redis: nil, worker: '', job_id: '', site: '', queue_name: ''
    )
      redis.multi do |conn|
        conn.srem("worker:#{site}:#{worker}:idx", job_id)
        conn.lrem("worker:#{site}:#{worker}", 1, job_id)
        conn.rpush("queue:#{site}:#{queue_name}", job_id)
        conn.hdel("queue:#{site}:#{queue_name}:claims", job_id)
        conn.hdel("queue:#{site}:#{queue_name}:claims:timestamps", job_id)
      end
    end

    private def purge_unknown_jobs!(redis: nil, site: '')
      return if site.empty?

      unknown_by_queue = {}

      redis.smembers("queues:#{site}").sort.each do |queue_name|
        queue_name = queue_name.to_s.strip
        next if queue_name.empty?

        claimed_job_ids = redis.hkeys("queue:#{site}:#{queue_name}:claims")
        found_in_db = job_model.select(:job_id)
                               .where(job_id: claimed_job_ids)
                               .map(:job_id)

        unknown_by_queue[queue_name] ||= []
        unknown_by_queue[queue_name] += (claimed_job_ids - found_in_db)
      end

      redis.smembers("workers:#{site}").sort.each do |worker|
        worker = worker.to_s.strip
        next if worker.empty?

        unknown_by_queue.each do |queue_name, job_ids|
          job_ids.each do |job_id|
            redis.multi do |conn|
              conn.srem("worker:#{site}:#{worker}:idx", job_id)
              conn.lrem("worker:#{site}:#{worker}", 1, job_id)
              conn.hdel("queue:#{site}:#{queue_name}:claims", job_id)
              conn.hdel("queue:#{site}:#{queue_name}:claims:timestamps", job_id)
            end
          end
        end
      end
    end
  end
end
