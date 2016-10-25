# frozen_string_literal: true
require 'job_board'
require_relative '../l2met_log'

module JobBoard
  class JobQueue
    include L2metLog

    Invalid = Class.new(StandardError)
    Error = Class.new(StandardError)

    def self.for_worker(redis: nil, worker: '', site: '')
      redis ||= JobBoard.redis
      unless redis.sismember("workers:#{site}", worker)
        raise Invalid, 'unknown worker'
      end
      redis.lrange("worker:#{site}:#{worker}", 0, -1)
    end

    def self.for_site(redis: nil, site: '')
      redis ||= JobBoard.redis
      raise Invalid, 'unknown site' unless redis.sismember('sites', site)

      results = {}
      redis.smembers("queues:#{site}").map(&:to_sym).map do |queue_name|
        results[queue_name] = for_queue(
          redis: redis, site: site, queue_name: queue_name
        )
      end
      results
    end

    def self.for_queue(redis: nil, site: '', queue_name: '')
      redis ||= JobBoard.redis
      unless redis.sismember("queues:#{site}", queue_name)
        raise Invalid, 'unknown queue'
      end

      claims = nil
      queued_ids = nil

      redis.multi do |conn|
        claims = conn.hgetall("queue:#{site}:#{queue_name}:claims")
        queued_ids = conn.lrange("queue:#{site}:#{queue_name}", 0, -1)
      end

      # rubocop:disable Style/NilComparison
      raise Error, 'unable to read queued ids' if queued_ids == nil
      raise Error, 'unable to read claims' if claims == nil
      # rubocop:enable Style/NilComparison

      results = {}
      claims.value.each do |job_id, worker|
        results[job_id] = {
          claimed_by: worker,
          updated_at: redis.hget(
            "queue:#{site}:#{queue_name}:claims:timestamps", job_id
          )
        }
      end

      queued_ids.value.each do |job_id|
        results[job_id] = { claimed_by: nil }
      end

      results
    end

    attr_reader :redis, :queue_name, :site, :ttl

    def initialize(redis: nil, queue_name: '', site: '',
                   ttl: JobBoard.config.worker_ttl)
      @redis = redis || JobBoard.redis
      @queue_name = queue_name
      @site = site
      @ttl = ttl
      # rubocop:disable Style/GuardClause
      if site.empty? || queue_name.empty?
        raise Invalid, 'missing site or queue name'
      end
      # rubocop:enable Style/GuardClause
    end

    def register(worker: '')
      redis.multi do |conn|
        conn.sadd('sites', site)
        conn.sadd("queues:#{site}", queue_name)
        conn.sadd("workers:#{site}", worker)
      end
    end

    def add(job_id: '')
      raise Invalid, 'missing job id' if job_id.to_s.empty?
      redis.lpush(queue_key, job_id.to_s)
    end

    def remove(job_id: '')
      raise Invalid, 'missing job id' if job_id.empty?

      result = redis.lrem(queue_key, 0, job_id)
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

    def claim(worker: '', max: 1, timeout: 5.0)
      raise Invalid, 'missing worker name' if worker.empty?
      raise Invalid, 'max must be > zero' unless max.positive?
      raise Invalid, 'timeout must be > zero' unless timeout.positive?

      start = Time.now
      new_claims = []

      loop do
        delta = Time.now - start
        if delta >= timeout
          log level: :warn, msg: 'timeout while claiming jobs',
              max: max, timeout: timeout, delta: time_delta
          break
        end

        break if new_claims.length >= max

        claimed = redis.rpoplpush(
          queue_key, worker_queue_list_key(worker: worker)
        )
        break if claimed.nil?
        new_claims << claimed
      end

      all_claims = redis.smembers(
        worker_index_set_key(worker: worker)
      ) + new_claims

      unless all_claims.empty?
        refresh_claims!(worker: worker, claimed: all_claims)
      end

      new_claims
    rescue => e
      log level: :error, msg: 'failure during claim', error: e.to_s

      begin
        new_claims.each do |job_id|
          redis.lpush(queue_key, job_id)
        end
      rescue => e
        log level: :error, msg: 'failed to push claims back', error: e.to_s
      end

      []
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
      @queue_key ||= "queue:#{site}:#{queue_name}"
    end

    def queue_job_claims_key
      @queue_job_claims_key ||= "queue:#{site}:#{queue_name}:claims"
    end

    def queue_job_claim_timestamps_key
      @queue_job_claim_timestamps_key ||=
        "queue:#{site}:#{queue_name}:claims:timestamps"
    end

    def worker_index_set_key(worker: '')
      "#{worker_queue_list_key(worker: worker)}:idx"
    end

    def worker_queue_list_key(worker: '')
      "worker:#{site}:#{worker}"
    end
  end
end
