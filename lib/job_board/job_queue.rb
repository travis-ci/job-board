# frozen_string_literal: true

require 'time'

require 'job_board'

module JobBoard
  class JobQueue
    Invalid = Class.new(StandardError)
    Error = Class.new(StandardError)

    def self.for_processor(redis: nil, site: '', queue_name: '', processor: '')
      redis ||= JobBoard.redis
      raise Invalid, 'unknown site' unless redis.sismember('sites', site)

      for_queue(
        site: site, queue_name: queue_name
      ).select do |job|
        job[:claimed_by] == processor
      end
    end

    def self.for_site(redis: nil, site: '')
      redis ||= JobBoard.redis
      raise Invalid, 'unknown site' unless redis.sismember('sites', site)

      results = []
      redis.smembers("queues:#{site}").map(&:to_sym).map do |queue_name|
        results << {
          queue: queue_name,
          jobs: for_queue(
            redis: redis, site: site, queue_name: queue_name
          )
        }
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

      jobs = []
      claims.value.each do |job_id, processor|
        jobs << {
          id: job_id,
          claimed_by: processor,
          updated_at: redis.hget(
            "queue:#{site}:#{queue_name}:claims:timestamps", job_id
          )
        }
      end

      queued_ids.value.each do |job_id|
        jobs << {
          id: job_id,
          claimed_by: nil
        }
      end

      jobs
    end

    attr_reader :redis_pool, :queue_name, :site, :ttl

    def initialize(redis_pool: nil, queue_name: '', site: '',
                   ttl: JobBoard.config.processor_ttl)
      @redis_pool = redis_pool || JobBoard.redis_pool
      @queue_name = queue_name
      @site = site
      @ttl = ttl
      # rubocop:disable Style/GuardClause
      if site.empty? || queue_name.empty?
        raise Invalid, 'missing site or queue name'
      end
      # rubocop:enable Style/GuardClause
    end

    def register(processor: '')
      processor = processor.to_s.strip
      raise Invalid, 'missing processor name' if processor.empty?

      redis_pool.with do |redis|
        redis.multi do |conn|
          conn.sadd('sites', site)
          conn.sadd("queues:#{site}", queue_name)
          conn.setex(processor_key(processor: processor), ttl, now)
        end
      end
    end

    def add(job_id: '')
      raise Invalid, 'missing job id' if job_id.to_s.empty?

      redis_pool.with do |redis|
        redis.multi do |conn|
          conn.sadd('sites', site)
          conn.sadd("queues:#{site}", queue_name)
          conn.lpush(queue_key, job_id.to_s)
        end
      end
    end

    def remove(job_id: '')
      raise Invalid, 'missing job id' if job_id.empty?

      redis_pool.with do |redis|
        result = redis.lrem(queue_key, 0, job_id)
        redis.multi do |conn|
          conn.hdel(queue_job_claims_key, job_id)
          conn.hdel(queue_job_claim_timestamps_key, job_id)
        end
        result
      end
    end

    def claim(processor: '')
      raise Invalid, 'missing processor name' if processor.empty?

      claimed = nil

      redis_pool.with do |redis|
        claimed = redis.rpop(queue_key)
        return nil if claimed.nil?

        refresh_claim(redis: redis, processor: processor, job_id: claimed)
      end

      claimed
    rescue => e
      JobBoard.logger.error('failure during claim', error: e.to_s)

      begin
        return nil if claimed.nil?
        redis_pool.with do |redis|
          redis.rpush(queue_key, claimed)
        end
      rescue => e
        JobBoard.logger.error('failed to push claim back', error: e.to_s)
      end

      nil
    end

    def claimed?(processor: '', job_id: '')
      processor = processor.to_s.strip
      return false if processor.empty?

      ret = { claimed: false }

      redis_pool.with do |redis|
        ret[:claimed] = processor_has_current_job_claim?(
          redis: redis, processor: processor, job_id: job_id
        ) && refresh_claim(
          redis: redis, processor: processor, job_id: job_id
        )
      end

      ret[:claimed]
    end

    private def processor_has_current_job_claim?(
      redis: nil, processor: '', job_id: nil
    )
      redis.exists(processor_key(processor: processor)) &&
      redis.hget(queue_job_claims_key, job_id) == processor
    end

    private def refresh_claim(redis: nil, processor: '', job_id: '')
      processor = processor.to_s.strip
      return if processor.empty?

      job_id = job_id.to_s.strip
      return if job_id.empty?

      result = redis.multi do |conn|
        conn.setex(processor_key(processor: processor), ttl, now)
        conn.hset(queue_job_claims_key, job_id, processor)
        conn.hset(queue_job_claim_timestamps_key, job_id, now)
      end

      result.fetch(0) == 'OK' &&
      [true, false].include?(result.fetch(1)) &&
      [true, false].include?(result.fetch(2))
    end

    private def now
      Time.now.utc.iso8601(7)
    end

    private def queue_key
      @queue_key ||= "queue:#{site}:#{queue_name}"
    end

    private def queue_job_claims_key
      @queue_job_claims_key ||= "queue:#{site}:#{queue_name}:claims"
    end

    private def queue_job_claim_timestamps_key
      @queue_job_claim_timestamps_key ||=
        "queue:#{site}:#{queue_name}:claims:timestamps"
    end

    private def processor_key(processor: '')
      "processor:#{site}:#{queue_name}:#{processor}"
    end
  end
end
