# frozen_string_literal: true
require 'job_board'

module JobBoard
  class JobQueueReconciler
    def initialize(redis: nil)
      @redis = redis || JobBoard.redis
    end

    attr_reader :redis

    def reconcile!
      start_time = Time.now
      stats = { sites: {} }

      redis.smembers('sites').map(&:to_sym).each do |site|
        stats[:sites][site] = {
          workers: {},
          queues: {}
        }

        reclaimed, claimed = reconcile_site!(site)
        stats[:sites][site][:reclaimed] = reclaimed
        stats[:sites][site][:workers].merge!(claimed)

        stats[:sites][site][:queues].merge!(measure(site))
      end

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
          redis.smembers("queues:#{site}").each do |name|
            reclaimed += reclaim!(worker: worker, site: site, name: name)
          end
          claimed[worker] = { claimed: 0 }
        end
      end

      [reclaimed, claimed]
    end

    def reclaim!(worker: nil, site: '', name: '')
      reclaimed = 0

      redis.hgetall("queue:#{site}:#{name}:claims").each do |job_id, claimer|
        next unless worker == claimer
        redis.multi do |conn|
          conn.lpush("queue:#{site}:#{name}", job_id)
          conn.hdel("queue:#{site}:#{name}:claims", job_id)
          reclaimed += 1
        end
      end

      reclaimed
    end

    def measure(site)
      measured = {}

      redis.smembers("queues:#{site}").each do |name|
        measured[name] = {
          queued: redis.llen("queue:#{site}:#{name}"),
          claimed: redis.hlen("queue:#{site}:#{name}:claims")
        }
      end

      measured
    end
  end
end
