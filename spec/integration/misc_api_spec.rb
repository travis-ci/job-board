# frozen_string_literal: true

describe 'Misc API', integration: true do
  let(:auth) { %w[guest guest] }

  before do
    authorize(*auth)
  end

  describe 'GET /' do
    it 'returns 200' do
      get '/'
      expect(last_response.status).to eql(200)
    end

    it 'is friendly' do
      get '/'
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('greeting')
      expect(response_body['greeting']).to match(/hello/)
    end
  end

  describe 'GET /latest-stats' do
    before do
      JobBoard.redis_pool.with do |conn|
        conn.set('latest-stats', '{"ok":"sure"}')
      end
    end

    it 'returns 200' do
      get '/latest-stats'
      expect(last_response.status).to eql(200)
    end

    it 'returns exactly what is stored in latest-stats' do
      get '/latest-stats'
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('ok')
      expect(response_body['ok']).to eql('sure')
    end
  end

  describe 'GET /search/jobs/:site' do
    before do
      queue = JobBoard::JobQueue.new(site: 'test', queue_name: 'test')
      queue.add(job_id: '1')
      queue.add(job_id: '2')
      queue.add(job_id: '3')
      queue.claim(processor: 'test-processor-1')
    end

    it 'returns 200' do
      get '/search/jobs/test'
      expect(last_response.status).to eql(200)
    end

    it 'has jobs and @site' do
      get '/search/jobs/test'
      response_body = JSON.parse(last_response.body)
      expect(response_body).to include('jobs')
      expect(response_body).to include('@site')
      expect(response_body['jobs']).to_not be_empty
      expect(response_body['@site']).to eql('test')
    end

    context 'with queue' do
      it 'returns 200' do
        get '/search/jobs/test?queue=test'
        expect(last_response.status).to eql(200)
      end

      it 'has jobs, @site, and @queue' do
        get '/search/jobs/test?queue=test'
        response_body = JSON.parse(last_response.body)
        expect(response_body).to include('jobs')
        expect(response_body).to include('@site')
        expect(response_body).to include('@queue')
        expect(response_body['jobs']).to_not be_empty
        expect(response_body['@site']).to eql('test')
        expect(response_body['@queue']).to eql('test')
      end

      context 'with processor' do
        it 'returns 200' do
          get '/search/jobs/test?queue=test&processor=test-processor-1'
          expect(last_response.status).to eql(200)
        end

        it 'has jobs, @site, @queue, and @processor' do
          get '/search/jobs/test?queue=test&processor=test-processor-1'
          response_body = JSON.parse(last_response.body)
          expect(response_body).to include('jobs')
          expect(response_body).to include('@site')
          expect(response_body).to include('@queue')
          expect(response_body).to include('@processor')
          expect(response_body['jobs']).to_not be_empty
          expect(response_body['@site']).to eql('test')
          expect(response_body['@queue']).to eql('test')
          expect(response_body['@processor']).to eql('test-processor-1')
          expect(response_body['jobs'].first['jobs'].first['claimed_by'])
            .to eql('test-processor-1')
        end
      end
    end
  end
end
