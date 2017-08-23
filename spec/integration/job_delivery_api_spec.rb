# frozen_string_literal: true

describe 'Job Delivery API', integration: true do
  let(:guest_auth) { %w[guest guest] }
  let(:admin_auth) { %w[important secret] }
  let(:auth_tokens) { %w[abc123 secret] }
  let(:from) { '7d725741-70e4-4f92-8750-8d482392e40c+worker@localhost' }
  let(:site) { 'test' }

  before do
    allow_any_instance_of(JobBoard::Auth).to receive(:alg)
      .and_return('none')
    allow_any_instance_of(JobBoard::Auth).to receive(:secret)
      .and_return(nil)
    allow_any_instance_of(JobBoard::Auth).to receive(:verify)
      .and_return(false)
    allow_any_instance_of(JobBoard::Auth).to receive(:auth_tokens)
      .and_return(auth_tokens)
    allow_any_instance_of(JobBoard::Services::CreateOrUpdateJob)
      .to receive(:assign_queue).and_return('lel')
    allow_any_instance_of(JobBoard::Services::FetchJob)
      .to receive(:fetch_job_script).and_return("#!/bin/bash\necho flah\n")
    allow_any_instance_of(JobBoard::Services::FetchJob)
      .to receive(:generate_jwt).and_return('FAFAFAF.BABABAB.DADADAD')
    allow_any_instance_of(JobBoard::Services::CreateJWT)
      .to receive(:private_key).and_return(nil)
    allow_any_instance_of(JobBoard::Services::CreateJWT)
      .to receive(:alg).and_return('none')
    JobBoard.config[:"job_state_#{site}_url"] = 'http://test.example.org'
    JobBoard.config[:"log_parts_#{site}_url"] = 'http://test.example.org'
  end

  describe 'POST /jobs' do
    before :each do
      JobBoard::Models::Job.where(queue: 'lel', site: site).delete
      JobBoard.redis.del("queue:#{site}:lel")
      JobBoard.redis.srem("queues:#{site}", 'lel')
      JobBoard.redis.del("queues:#{site}:lel:processors:#{from}")

      rand(4..9).times do |n|
        job_id = "#{Time.now.to_i}#{n}"

        JobBoard::Services::CreateOrUpdateJob.run(
          job: {
            'id' => job_id,
            'data' => {
              'config' => {
                'language' => 'rubby'
              },
              'job' => {
                'id' => job_id
              },
              'repository' => {
                'slug' => 'very/test'
              }
            }
          },
          site: site
        )
      end
    end

    after :each do
      JobBoard::Models::Job.where(queue: 'lel', site: site).delete
    end

    it 'rejects guest auth' do
      authorize(*guest_auth)
      post '/jobs?queue=lel', JSON.dump(jobs: []),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_FROM' => from,
           'HTTP_TRAVIS_SITE' => site
      expect(last_response.status).to eq(403)
    end

    it 'returns 200' do
      authorize(*admin_auth)
      post '/jobs?queue=lel', JSON.dump(jobs: []),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_FROM' => from,
           'HTTP_TRAVIS_SITE' => site
      expect(last_response.status).to eq(200)
    end

    it 'includes queue metadata' do
      authorize(*admin_auth)
      post '/jobs?queue=lel', JSON.dump(jobs: []),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_FROM' => from,
           'HTTP_TRAVIS_SITE' => site
      response_body = JSON.parse(last_response.body)
      expect(response_body['@queue']).to eq('lel')
    end

    it 'returns the expected number of jobs' do
      authorize(*admin_auth)
      post '/jobs?queue=lel', JSON.dump(jobs: []),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_FROM' => from,
           'HTTP_TRAVIS_SITE' => site
      response_body = JSON.parse(last_response.body)
      expect(response_body['jobs']).to_not be_nil
      expect(response_body['jobs'].length).to eq(1)
    end

    xit 'records allocations for the processor' do
      authorize(*admin_auth)
      post '/jobs?queue=lel', JSON.dump(jobs: []),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_FROM' => from,
           'HTTP_TRAVIS_SITE' => site
      response_body = JSON.parse(last_response.body)
      expect(response_body['jobs']).to_not be_nil
      expect(response_body['jobs'].sort).to eql(
        JobBoard::JobQueue.for_processor(
          site: site,
          queue_name: 'lel',
          processor: from
        ).map { |entry| entry[:id] }.sort
      )
    end
  end

  describe 'POST /jobs/add' do
    let(:job_id) { Time.now.to_i.to_s }
    let :job do
      {
        '@type' => 'job',
        'id' => job_id,
        'data' => {
          'queue' => 'builds.lel',
          'config' => {
            'language' => 'rubby',
            'os' => 'lanerks'
          },
          'job' => {
            'id' => job_id
          },
          'repository' => {
            'slug' => 'very/test'
          }
        }
      }
    end

    before :each do
      JobBoard::Models::Job.where(queue: 'lel', site: site).delete
      JobBoard.redis.del("queue:#{site}:lel")
      JobBoard.redis.srem("queues:#{site}", 'lel')
    end

    after :each do
      JobBoard::Models::Job.where(queue: 'lel', site: site).delete
    end

    it 'rejects guest auth' do
      authorize(*guest_auth)
      post '/jobs/add', JSON.dump(job),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_TRAVIS_SITE' => site
      expect(last_response.status).to eq(403)
    end

    it 'returns 201' do
      authorize(*admin_auth)
      post '/jobs/add', JSON.dump(job),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_TRAVIS_SITE' => site
      expect(last_response.status).to eq(201)
    end

    it 'responds with nothing' do
      authorize(*admin_auth)
      post '/jobs/add', JSON.dump(job),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_TRAVIS_SITE' => site
      expect(last_response.body.length).to eq(0)
    end

    it 'adds the job to the database' do
      authorize(*admin_auth)
      post '/jobs/add', JSON.dump(job),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_TRAVIS_SITE' => site
      expect(JobBoard::Models::Job.where(queue: 'lel', site: site).count)
        .to eq(1)
    end

    it 'adds the job to the assigned queue' do
      authorize(*admin_auth)
      post '/jobs/add', JSON.dump(job),
           'HTTP_CONTENT_TYPE' => 'application/json',
           'HTTP_TRAVIS_SITE' => site
      expect(JobBoard.redis.llen("queue:#{site}:lel")).to eq(1)
    end
  end

  describe 'GET /jobs/:job_id' do
    let(:job_id) { Time.now.to_i.to_s }
    let(:from) { '7d725741-70e4-4f92-8750-8d482392e40c+worker@localhost' }

    before :each do
      JobBoard::Models::Job.where(queue: 'lel', site: site).delete
      JobBoard.redis.multi do |conn|
        conn.del("queue:#{site}:lel")
        conn.srem("queues:#{site}", 'lel')
      end

      JobBoard::Services::CreateOrUpdateJob.run(
        job: {
          '@type' => 'job',
          'id' => job_id,
          'data' => {
            'vm_type' => 'default',
            'queue' => 'builds.lel',
            'config' => {
              'os' => 'mcohess',
              'language' => 'pythorn'
            },
            'job' => {
              'id' => job_id
            },
            'repository' => {
              'slug' => 'testy/testersons'
            },
            'timeouts' => {
              'hard_limit' => 10_800,
              'log_silence' => 900
            }
          }
        },
        site: site
      )

      JobBoard::Services::AllocateJob.run(
        from: from,
        queue_name: 'lel',
        site: site
      )
    end

    after :each do
      JobBoard::Models::Job.where(queue: 'lel', site: site).delete
    end

    it 'rejects guest auth' do
      authorize(*guest_auth)
      get "/jobs/#{job_id}", nil,
          'HTTP_FROM' => from, 'HTTP_TRAVIS_SITE' => site
      expect(last_response.status).to eq(403)
    end

    it 'responds 200' do
      authorize(*admin_auth)
      get "/jobs/#{job_id}", nil,
          'HTTP_FROM' => from, 'HTTP_TRAVIS_SITE' => site
      expect(last_response.status).to eq(200)
    end

    it 'includes a job script' do
      authorize(*admin_auth)
      get "/jobs/#{job_id}", nil,
          'HTTP_FROM' => from, 'HTTP_TRAVIS_SITE' => site
      response_body = JSON.parse(last_response.body)
      expect(response_body['job_script']).to_not be_nil
      job_script = response_body.fetch('job_script')
      expect(job_script['name']).to eq('main')
      expect(job_script['encoding']).to eq('base64')
      expect(job_script['content'].length).to be_positive
      expect(Base64.decode64(job_script['content'])).to match(/bash/)
    end

    it 'includes upstream job data' do
      authorize(*admin_auth)
      get "/jobs/#{job_id}", nil,
          'HTTP_FROM' => from, 'HTTP_TRAVIS_SITE' => site
      response_body = JSON.parse(last_response.body)
      expect(response_body['data']).to_not be_nil
      expect(response_body['data']['config']).to_not be_nil
      config = response_body.fetch('data').fetch('config')
      expect(config['language']).to eq('pythorn')
      expect(config['os']).to eq('mcohess')
    end

    %w[job_state_url log_parts_url jwt @type].each do |key|
      it "includes a #{key.inspect} key" do
        authorize(*admin_auth)
        get "/jobs/#{job_id}", nil,
            'HTTP_FROM' => from, 'HTTP_TRAVIS_SITE' => site
        response_body = JSON.parse(last_response.body)
        expect(response_body[key]).to_not be_nil
      end
    end
  end

  describe 'DELETE /jobs/:job_id' do
    let(:job_id) { Time.now.to_i.to_s }
    let(:jwt) { JobBoard::Services::CreateJWT.run(job_id: job_id) }

    before :each do
      JobBoard::Models::Job.where(job_id: job_id, site: site).delete
      JobBoard::Services::CreateOrUpdateJob.run(
        job: {
          'id' => job_id,
          'data' => {
            'config' => {
              'language' => 'rubby',
              'os' => 'mcohess'
            },
            'job' => {
              'id' => job_id
            },
            'repository' => {
              'slug' => 'very/test'
            }
          }
        },
        site: site
      )
    end

    after :each do
      JobBoard::Models::Job.where(job_id: job_id, site: site).delete
    end

    it 'rejects guest auth' do
      authorize(*guest_auth)
      delete "/jobs/#{job_id}", nil,
             'HTTP_FROM' => from,
             'HTTP_TRAVIS_SITE' => site
      expect(last_response.status).to eq(403)
    end

    it 'deletes a job' do
      delete "/jobs/#{job_id}", nil,
             'HTTP_FROM' => from,
             'HTTP_AUTHORIZATION' => "Bearer #{jwt}",
             'HTTP_TRAVIS_SITE' => site
      expect(last_response.status).to eq(204)
      expect(JobBoard::Models::Job.where(job_id: job_id, site: site).count)
        .to be_zero
    end
  end
end
