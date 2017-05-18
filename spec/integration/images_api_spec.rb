# frozen_string_literal: true

describe 'Images API', integration: true do
  let(:auth) { %w[guest guest] }
  let(:auth_tokens) { %w[abc123 secret] }

  before do
    allow_any_instance_of(JobBoard::ImagesAPI).to receive(:images_name_format)
      .and_return(/^test-im.*/)
    allow_any_instance_of(JobBoard::Auth).to receive(:auth_tokens)
      .and_return(auth_tokens)
    authorize(*auth)
  end

  describe 'GET /images' do
    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete

      3.times do |n|
        created = JobBoard::Services::CreateImage.run(
          params: {
            'infra' => 'test',
            'name' => "test-image-#{n}",
            'is_default' => n.zero?,
            'tags' => {
              'foo' => 'bar',
              'production' => (n.even? ? 'nope' : 'yep'),
              'last_in' => (n == 2 ? 'yep' : 'nope')
            }
          }
        )
        created.created_at += (300 * n)
        created.save_changes
      end
    end

    {
      'with infra' => ['/images?infra=test', 3],
      'with infra & default limit' => ['/images?infra=test', 3],
      'with infra & name' =>
        ['/images?infra=test&name=test-image-0', 1],
      'with infra & name regex' =>
        ['/images?infra=test&name=test-.*', 3],
      'with nonmatched conditions' =>
        ['/images?infra=test&name=foo', 0],
      'with infra & tags production:yep' =>
        ['/images?infra=test&tags=production:yep', 1],
      'with infra & tags production:nope' =>
        ['/images?infra=test&tags=production:nope', 2],
      'with infra & tags foo:bar' =>
        ['/images?infra=test&tags=foo:bar', 3]
    }.each do |desc, (path, count)|
      context desc do
        it 'returns 200' do
          get path
          expect(last_response.status).to eql(200)
        end

        it "returns #{count} image#{count > 1 ? 's' : ''}" do
          get path
          response_body = JSON.parse(last_response.body)
          expect(response_body['data']).to_not be_nil
          expect(response_body['data'].length).to eql(count)
          expect(response_body['data']).to eql(
            response_body['data'].sort_by { |i| i['created_date'] }
          )
          response_body['data'].each do |image|
            expect(image['tags']).to_not be_nil
            expect(image['tags']['foo']).to eql('bar')
          end
        end
      end
    end

    context 'when multiple results match' do
      it 'returns the most recently tagged image first' do
        get '/images?infra=test&limit=2'
        response_body = JSON.parse(last_response.body)
        expect(response_body['data']).to_not be_nil
        expect(response_body['data'].length).to eql(2)
        expect(response_body['data'].fetch(0).fetch('tags'))
          .to include('last_in' => 'yep')
      end
    end

    context 'when no infra param is provided' do
      it 'returns 400' do
        get '/images'
        expect(last_response.status).to eql(400)
      end

      it 'returns an error message' do
        get '/images'
        expect(JSON.parse(last_response.body)['message']).to_not be_empty
      end
    end

    it 'supports fields specification' do
      get '/images?infra=test&fields[images]=name'
      response_body = JSON.parse(last_response.body)
      expect(response_body).to_not be_empty
      expect(response_body['data']).to_not be_nil
      response_body['data'].each do |image|
        expect(image.keys).to eql(%w[name])
      end
    end
  end

  describe 'POST /images/search' do
    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete

      3.times do |n|
        created = JobBoard::Services::CreateImage.run(
          params: {
            'infra' => 'test',
            'name' => "test-image-#{n}",
            'is_default' => n.zero?,
            'tags' => {
              'foo' => 'bar',
              'production' => (n.even? ? 'nope' : 'yep'),
              'last_in' => (n == 2 ? 'yep' : 'nope')
            }
          }
        )
        created.created_at += (300 * n)
        created.save_changes
      end
    end

    {
      'with infra & wildcard name' => [%w[infra=test&name=.*], 1],
      'with infra & limit=3' =>
        [%w[infra=test&limit=3], 3],
      'with infra & tags' =>
        [%w[infra=test&tags=foo:bar,production:yep], 1],
      'with infra, tags, limit=3, & is_default=false' =>
        [%w[infra=test&tags=foo:bar&is_default=false&limit=3], 3],
      'with infra, tags, limit=3, & is_default=true' =>
        [%w[infra=test&tags=foo:bar&is_default=true&limit=3], 1]
    }.each do |desc, (body, count)|
      context desc do
        it 'returns 200' do
          post '/images/search', body.join("\n"),
               'CONTENT_TYPE' => 'text/uri-list'
          expect(last_response.status).to eql(200)
        end

        it "returns an array of #{count} image#{count > 1 ? 's' : ''}" do
          post '/images/search', body.join("\n"),
               'CONTENT_TYPE' => 'text/uri-list'

          response_body = JSON.parse(last_response.body)
          expect(response_body['data']).to_not be_nil
          expect(response_body['data']).to_not be_empty
          expect(response_body['data'].length).to eql(count)
          expect(response_body['data']).to eql(
            response_body['data'].sort_by { |i| i['created_date'] }
          )
        end
      end
    end

    {
      'when no queries include "infra"' => %w[foo=test&limit=1 name=test-image]
    }.each do |desc, body|
      context desc do
        it 'returns empty dataset' do
          post '/images/search', body.join("\n"),
               'CONTENT_TYPE' => 'text/uri-list'

          response_body = JSON.parse(last_response.body)
          expect(response_body['data']).to_not be_nil
          expect(response_body['data']).to be_empty
        end
      end
    end

    it 'supports fields specification' do
      post '/images/search',
           %w(
             infra=test&fields[images]=name
             infra=test&name=test-image&fields[images]=name
           ).join("\n"),
           'CONTENT_TYPE' => 'text/uri-list'

      response_body = JSON.parse(last_response.body)
      expect(response_body).to_not be_empty
      expect(response_body['data']).to_not be_nil
      response_body['data'].each do |image|
        expect(image.keys).to eql(%w[name])
      end
    end
  end

  describe 'POST /images' do
    let(:auth) { %w[admin secret] }

    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete
    end

    {
      'with infra & name' => '/images?infra=test&name=test-image',
      'with infra, name, & is_default' =>
        '/images?infra=test&name=test-image&is_default=true',
      'with infra, name, & tags' =>
        '/images?infra=test&name=test-image&tags=foo:bar'
    }.each do |desc, path|
      context desc do
        it 'returns 201' do
          post path
          expect(last_response.status).to eql(201)
        end

        it 'creates a new image' do
          expect { post path }.to change { JobBoard::Models::Image.count }
        end

        context 'with guest auth' do
          let(:auth) { %w[guest guest] }

          it 'returns 403' do
            post path
            expect(last_response.status).to eql(403)
          end

          it 'does not create a new image' do
            expect { post path }.to_not change { JobBoard::Models::Image.count }
          end
        end
      end
    end

    {
      'when no infra param is provided' => '/images',
      'when no name param is provided' => '/images?infra=test',
      'when name is invalid' => '/images?infra=test&name=bogus'
    }.each do |desc, path|
      context desc do
        it 'returns 400' do
          post path
          expect(last_response.status).to eql(400)
        end

        it 'creates no image' do
          expect { post path }.to_not change { JobBoard::Models::Image.count }
        end
      end
    end
  end

  describe 'PUT /images' do
    let(:auth) { %w[admin secret] }

    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete

      3.times do |n|
        created = JobBoard::Services::CreateImage.run(
          params: {
            'infra' => 'test',
            'name' => "test-image-#{n}",
            'is_default' => n.zero?,
            'tags' => {
              'foo' => 'bar',
              'production' => (n.even? ? 'nope' : 'yep'),
              'last_in' => (n == 2 ? 'yep' : 'nope')
            }
          }
        )
        created.created_at += (300 * n)
        created.save_changes
      end
    end

    {
      'with infra & nonexistent name' =>
        ['/images?infra=test&name=test-image-99', 404, nil, nil],
      'with infra, name & tags production:yep' =>
        [
          '/images?infra=test&name=test-image-0&tags=production:totes',
          200,
          { 'production' => 'totes' },
          false
        ],
      'with infra, name & empty tags' =>
        [
          '/images?infra=test&name=test-image-0&tags=',
          200,
          {},
          false
        ],
      'with infra, name, is_default=true, & tags production:sure' =>
        [
          '/images?infra=test&name=test-image-0&' \
            'tags=production:sure&is_default=true',
          200,
          { 'production' => 'sure' },
          true
        ]
    }.each do |desc, (path, status, tags, is_default)|
      context desc do
        it "returns #{status}" do
          put path
          expect(last_response.status).to eql(status)
        end

        if status < 299
          it 'updates image' do
            put path
            response_body = JSON.parse(last_response.body)
            expect(response_body).to_not be_empty
            expect(response_body['data']).to_not be_nil
            expect(response_body['data'].length).to eql(1)
            image = response_body['data'].fetch(0)
            expect(image['tags']).to eql(tags)
            expect(image['is_default']).to eql(is_default)
          end
        end

        context 'with guest auth' do
          let(:auth) { %w[guest guest] }

          it 'returns 403' do
            put path
            expect(last_response.status).to eql(403)
          end
        end
      end
    end
  end

  describe 'PUT /images/multi' do
    let(:auth) { %w[admin secret] }

    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete

      5.times do |n|
        created = JobBoard::Services::CreateImage.run(
          params: {
            'infra' => 'test',
            'name' => "test-image-#{n}",
            'is_default' => n.zero?,
            'tags' => {
              'foo' => 'bar',
              'production' => (n.even? ? 'nope' : 'yep'),
              'last_in' => (n == 2 ? 'yep' : 'nope')
            }
          }
        )
        created.created_at += (300 * n)
        created.save_changes
      end
    end

    {
      'when all updates match' => [
        %w[
          infra=test&name=test-image-1&tags=foo:baz
          infra=test&name=test-image-2&tags=foo:nah,production:ja
          infra=test&name=test-image-3&tags=foo:um,production:fuh
        ], 200
      ],
      'when any update does not match' => [
        %w[
          infra=test&name=test-image-2&tags=foo:nah,production:ja
          infra=test&name=test-image-3&tags=foo:um,production:fuh
          infra=test&name=test-image-99&tags=foo:baz
        ], 400
      ],
      'with invalid input' => [%W[infra=test\xba\xba\xda\xda], 400]
    }.each do |desc, (body, status)|
      context desc do
        it "returns #{status}" do
          put '/images/multi', body.join("\n"),
              'CONTENT_TYPE' => 'text/uri-list'
          expect(last_response.status).to eql(status)
        end

        if status < 299
          it 'has a data response body with updated images' do
            put '/images/multi', body.join("\n"),
                'CONTENT_TYPE' => 'text/uri-list'
            response_body = JSON.parse(last_response.body)
            expect(response_body).to_not be_empty
            expect(response_body).to include('data')
            expect(response_body['data']).to_not be_nil
            expect(response_body['data'].length).to eql(body.length)

            body_params = body.map { |l| JobBoard::ImageParams.parse(l) }
            response_body['data'].zip(body_params).each do |params, image|
              expect(params['name']).to eql(image['name'])
              expect(params['infra']).to eql(image['infra'])
              expect(params['tags']).to eql(image['tags'])
            end
          end
        end

        if status >= 300
          it 'has an error response body' do
            put '/images/multi', body.join("\n"),
                'CONTENT_TYPE' => 'text/uri-list'
            expect(last_response.body).to_not be_empty
            response_body = JSON.parse(last_response.body)
            expect(response_body).to include('error')
            expect(response_body['error']).to_not be_empty
          end

          it 'does not update images' do
            put '/images/multi', body.join("\n"),
                'CONTENT_TYPE' => 'text/uri-list'

            get '/images?infra=test&tags=foo:baz'
            expect(last_response.status).to eql(200)
            expect(last_response.body).to_not be_empty
            response_body = JSON.parse(last_response.body)
            expect(response_body).to include('data')
            expect(response_body['data']).to be_empty
          end
        end
      end
    end
  end

  describe 'DELETE /images' do
    let(:auth) { %w[admin secret] }

    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete

      3.times do |n|
        created = JobBoard::Services::CreateImage.run(
          params: {
            'infra' => 'test',
            'name' => "test-image-#{n}",
            'is_default' => n.zero?,
            'tags' => {
              'foo' => 'bar',
              'production' => (n.even? ? 'nope' : 'yep'),
              'last_in' => (n == 2 ? 'yep' : 'nope')
            }
          }
        )
        created.created_at += (300 * n)
        created.save_changes
      end
    end

    {
      'with infra & name' =>
        ['/images?infra=test&name=test-image-0&limit=10', 204],
      'with infra, name, & tags production:yep' =>
        ['/images?infra=test&name=test-image-0' \
         '&tags=production:yep&limit=0', 204]
    }.each do |desc, (path, status)|
      context desc do
        it "returns #{status}" do
          delete path
          expect(last_response.status).to eql(status)
        end

        it 'deletes matching image' do
          expect do
            delete path
            expect(last_response.body).to be_empty
          end.to change { JobBoard::Models::Image.count }.by(-1)
        end

        context 'with guest auth' do
          let(:auth) { %w[guest guest] }

          it 'returns 403' do
            delete path
            expect(last_response.status).to eql(403)
          end

          it 'does not delete matching image(s)' do
            expect do
              delete path
              expect(last_response.body).to be_empty
            end.to_not change { JobBoard::Models::Image.count }
          end
        end
      end
    end
  end
end
