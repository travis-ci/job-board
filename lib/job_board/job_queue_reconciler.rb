# frozen_string_literal: true
require 'job_board'

require 'l2met-log'

module JobBoard
  class JobQueueReconciler
    include L2met::Log

    def initialize(redis: nil)
      @redis = redis || JobBoard.redis
    end

    attr_reader :redis

    def reconcile!
      log msg: 'starting reconciliation process'
      start_time = Time.now
      stats = { sites: {} }

      redis.smembers('sites').map(&:to_sym).each do |site|
        stats[:sites][site] = {
          workers: {},
          queues: {}
        }

        log msg: 'reconciling', site: site
        reclaimed, claimed = reconcile_site!(site)

        log msg: 'reclaimed jobs', site: site, n: reclaimed
        log msg: 'setting worker claimed jobs', site: site
        stats[:sites][site][:reclaimed] = reclaimed
        stats[:sites][site][:workers].merge!(claimed)

        log msg: 'fetching queue stats', site: site
        stats[:sites][site][:queues].merge!(measure(site))
      end

      log msg: 'finished with reconciliation process'
      stats.merge(time: "#{Time.now - start_time}s")
    end

    private

    def reconcile_site!(site)
      reclaimed = 0
      claimed = {}

      redis.smembers("workers:#{site}").each do |worker|
        if redis.exists("worker:#{site}:#{worker}")
          claimed[worker] = {
            claimed: redis.llen("worker:#{site}:#{worker}")
          }
        else
          redis.smembers("queues:#{site}").each do |queue_name|
            reclaimed += reclaim!(
              worker: worker, site: site, queue_name: queue_name
            )
          end
          claimed[worker] = { claimed: 0 }
        end
      end

      [reclaimed, claimed]
    end

    def reclaim!(worker: nil, site: '', queue_name: '')
      reclaimed = 0

      claims = redis.hgetall("queue:#{site}:#{queue_name}:claims")
      claims.each do |job_id, claimer|
        next unless worker == claimer
        redis.multi do |conn|
          conn.lpush("queue:#{site}:#{queue_name}", job_id)
          conn.hdel("queue:#{site}:#{queue_name}:claims", job_id)
          reclaimed += 1
        end
      end

      reclaimed
    end

    def measure(site)
      measured = {}

      redis.smembers("queues:#{site}").each do |queue_name|
        measured[queue_name] = {
          queued: redis.llen("queue:#{site}:#{queue_name}"),
          claimed: redis.hlen("queue:#{site}:#{queue_name}:claims")
        }
      end

      measured
    end
  end
end
