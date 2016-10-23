# frozen_string_literal: true
require 'job_board'

module JobBoard
  class JobQueue
    Invalid = Class.new(StandardError)

    def self.for_worker(redis: nil, worker: '', site: '')
      redis ||= JobBoard.redis
      raise Invalid, 'unknown worker' unless
        redis.sismember("workers:#{site}", worker)
      redis.lrange("worker:#{site}:#{worker}", 0, -1)
    end

    def self.for_site(redis: nil, site: '')
      redis ||= JobBoard.redis
      raise Invalid, 'unknown site' unless redis.sismember('sites', site)

      results = {}
      redis.smembers("queues:#{site}").map(&:to_sym).map do |name|
        results[name] = for_queue(redis: redis, site: site, name: name)
      end
      results
    end

    def self.for_queue(redis: nil, site: '', name: '')
      redis ||= JobBoard.redis
      raise Invalid, 'unknown queue' unless
        redis.sismember("queues:#{site}", name)

      results = {}
      redis.hgetall("queue:#{site}:#{name}:claims").each do |job_id, worker|
        results[job_id] = {
          claimed_by: worker,
          updated_at: redis.hget(
            "queue:#{site}:#{name}:claims:timestamps", job_id
          )
        }
      end

      redis.lrange("queue:#{site}:#{name}", 0, -1).each do |job_id|
        results[job_id] = { claimed_by: nil }
      end

      results
    end

    attr_reader :redis, :name, :site, :ttl

    def initialize(redis: nil, name: '', site: '',
                   ttl: JobBoard.config.worker_ttl)
      @redis = redis || JobBoard.redis
      @name = name
      @site = site
      @ttl = ttl
      raise Invalid, 'missing site or queue name' if site.empty? || name.empty?
    end

    def register(worker: '')
      redis.multi do |conn|
        conn.sadd('sites', site)
        conn.sadd("queues:#{site}", name)
        conn.sadd("workers:#{site}", worker)
      end
    end

    def add(job_id: '')
      raise Invalid, 'missing job id' if job_id.to_s.empty?
      redis.lpush(queue_key, job_id.to_s)
    end

    def remove(job_id: '')
      raise Invalid, 'missing job id' if job_id.empty?

      result = redis.lrem(queue_key, 1, job_id)
      workers = redis.smembers("workers:#{site}")
      redis.multi do |conn|
        workers.each do |worker|
          conn.srem("worker:#{site}:#{worker}:idx", job_id)
          conn.lrem("worker:#{site}:#{worker}", 1, job_id)
        end
        conn.hdel(queue_job_claims_key, job_id)
        conn.hdel(queue_job_claim_timestamps_key, job_id)
      end
      result
    end

    def claim(worker: '')
      claimed = redis.rpoplpush(
        queue_key, worker_queue_list_key(worker: worker)
      )
      return nil if claimed.nil?

      refresh_claims!(
        worker: worker,
        claimed: redis.smembers(
          worker_index_set_key(worker: worker)
        ) + [claimed]
      )
      claimed
    end

    def check_claims(worker: '', job_ids: [])
      claimed = []

      job_ids.each do |job_id|
        # NOTE: I'm pretty sure there's a race condition here, but I don't know
        # how likely it is or the severity of the outcome.  Using a lua script
        # might be the answer.  ~meatballhat
        if redis.hget(queue_job_claims_key, job_id) == worker &&
           redis.sismember(worker_index_set_key(worker: worker), job_id)
          redis.hset(queue_job_claim_timestamps_key, job_id, now)
          claimed << job_id
          next
        end
        redis.srem(worker_index_set_key(worker: worker), job_id)
      end

      redis.multi do |conn|
        conn.expire(worker_index_set_key(worker: worker), ttl)
        conn.expire(worker_queue_list_key(worker: worker), ttl)
      end

      claimed
    end

    private

    def refresh_claims!(worker: '', claimed: [])
      claimed_map = claimed.map { |job_id| [job_id, worker] }
      redis.multi do |conn|
        conn.sadd(worker_index_set_key(worker: worker), claimed)
        conn.expire(worker_index_set_key(worker: worker), ttl)
        conn.expire(worker_queue_list_key(worker: worker), ttl)
        conn.hmset(queue_job_claims_key, claimed_map.flatten)
        conn.hmset(
          queue_job_claim_timestamps_key,
          claimed_map.map { |job_id, _| [job_id, now] }.flatten
        )
      end
    end

    def now
      Time.now.utc.iso8601(7)
    end

    def queue_key
      @queue_key ||= "queue:#{site}:#{name}"
    end

    def queue_job_claims_key
      @queue_job_claims_key ||= "queue:#{site}:#{name}:claims"
    end

    def queue_job_claim_timestamps_key
      @queue_job_claim_timestamps_key ||=
        "queue:#{site}:#{name}:claims:timestamps"
    end

    def worker_index_set_key(worker: '')
      "#{worker_queue_list_key(worker: worker)}:idx"
    end

    def worker_queue_list_key(worker: '')
      "worker:#{site}:#{worker}"
    end
  end
end
