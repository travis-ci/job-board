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
            processors: [],
            queues: []
          }

          JobBoard.logger.info('reconciling', site: site)
          reclaimed, claimed = reconcile_site!(redis: redis, site: site)

          total_capacity = measure_capacity(redis: redis, site: site)
          total_claimed = claimed.values.map(&:length).reduce(:+) || 0
          site_def.merge!(
            capacity: total_capacity,
            claimed: total_claimed,
            available: total_capacity - total_claimed
          )

          JobBoard.logger.info('reclaimed jobs', site: site, n: reclaimed.length)
          site_def[:reclaimed] = reclaimed.length
          site_def[:reclaimed_ids] = reclaimed if with_ids

          claimed.each do |_, claimed_for_queue|
            claimed_for_queue.each do |processor_name, jobs|
              site_def[:processors] << {
                name: processor_name,
                claimed: jobs.length
              }
            end
          end

          JobBoard.logger.info('fetching queue stats', site: site)
          site_def[:queues] = measure_queues(redis: redis, site: site)

          stats[:sites] << site_def
        end

        JobBoard.logger.info('finished with reconciliation process')
        stats.merge(time: "#{Time.now - start_time}s")
      end
    end

    private def reconcile_site!(redis: nil, site: '', cutoff_seconds: 120)
      reclaimed = []
      claimed = {}

      redis.smembers("queues:#{site}").sort.each do |queue_name|
        queue_name = queue_name.to_s.strip
        next if queue_name.empty?

        queue_reclaimed, queue_claimed = reclaim_for_queue(
          redis: redis, site: site, queue_name: queue_name,
          cutoff_seconds: cutoff_seconds
        )
        reclaimed += queue_reclaimed
        claimed[queue_name] = queue_claimed
      end

      [reclaimed, claimed]
    end

    private def reclaim_for_queue(redis: nil, site: '', queue_name: '',
                                  cutoff_seconds: 120)
      reclaimed_for_queue = []
      claimed_by_id = redis.hgetall("queue:#{site}:#{queue_name}:claims")
      claimed_by_processor = {}
      claimed_by_id.each do |job_id, processor_name|
        claimed_by_processor[processor_name] ||= []
        claimed_by_processor[processor_name] << job_id
      end

      now = Time.now.utc
      redis.hgetall(
        "queue:#{site}:#{queue_name}:claims:timestamps"
      ).each do |job_id, timestamp|
        parsed_ts = safe_time_parse(timestamp)
        processor_name = claimed_by_id[job_id]
        if parsed_ts.nil?
          JobBoard.logger.debug(
            'reclaiming', reason: 'invalid timestamp', job_id: job_id
          )
          reclaimed_for_queue << job_id
        elsif (now - parsed_ts) > cutoff_seconds
          JobBoard.logger.debug(
            'reclaiming', reason: 'stale', job_id: job_id
          )
          reclaimed_for_queue << job_id
        elsif !redis.exists(
          "queues:#{site}:#{queue_name}:processor:#{processor_name}"
        )
          JobBoard.logger.debug(
            'reclaiming', reason: 'expired processor', job_id: job_id
          )
          claimed_by_processor[processor_name].delete(job_id)
          reclaimed_for_queue << job_id
        end
      end

      unless reclaimed_for_queue.empty?
        redis.multi do |conn|
          conn.hdel(
            "queue:#{site}:#{queue_name}:claims", reclaimed_for_queue
          )
          conn.hdel(
            "queue:#{site}:#{queue_name}:claims:timestamps",
            reclaimed_for_queue
          )
        end
      end

      claimed_by_processor.reject! { |_, v| v.empty? }
      [reclaimed_for_queue, claimed_by_processor]
    end

    private def measure_capacity(redis: nil, site: '')
      total = 0

      redis.smembers("queues:#{site}").sort.each do |queue_name|
        redis.scan_each(
          match: "queues:#{site}:#{queue_name}:processor:*"
        ).each do
          total += 1
        end
      end

      total
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

        redis.scan_each(
          match: "queues:#{site}:#{queue_name}:processor:*"
        ) do
          queue_capacity += 1
        end

        measured << queue_def.merge(
          capacity: queue_capacity,
          available: queue_capacity - queue_def[:claimed]
        )
      end

      measured
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

      unknown_by_queue.each do |queue_name, job_ids|
        job_ids.each do |job_id|
          redis.multi do |conn|
            conn.hdel("queue:#{site}:#{queue_name}:claims", job_id)
            conn.hdel("queue:#{site}:#{queue_name}:claims:timestamps", job_id)
          end
        end
      end
    end

    private def safe_time_parse(timestamp)
      Time.parse(timestamp)
    rescue => e
      warn e
      nil
    end
  end
end
