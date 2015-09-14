describe 'Images API', integration: true do
  describe 'GET /images' do
    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete

      3.times do |n|
        JobBoard::Services::CreateImage.run(
          params: {
            'infra' => 'test',
            'name' => "test-image-#{n}",
            'is_default' => (n == 0),
            'tags' => {
              'foo' => 'bar',
              'production' => (n.even? ? 'nope' : 'yep')
            }
          }
        )
      end
    end

    {
      'with infra' => ['/images?infra=test&limit=10', 3],
      'with infra & default limit' => ['/images?infra=test', 1],
      'with infra & name' =>
        ['/images?infra=test&name=test-image-0&limit=10', 1],
      'with infra & name regex' =>
        ['/images?infra=test&name=test-.*&limit=10', 3],
      'with nonmatched conditions' =>
        ['/images?infra=test&name=foo&limit=10', 0],
      'with infra & tags production:yep' =>
        ['/images?infra=test&tags=production:yep&limit=10', 1],
      'with infra & tags production:nope' =>
        ['/images?infra=test&tags=production:nope&limit=10', 2],
      'with infra & tags foo:bar' =>
        ['/images?infra=test&tags=foo:bar&limit=10', 3]
    }.each do |desc, (path, count)|
      context desc do
        it 'returns 200' do
          get path
          expect(last_response.status).to eql(200)
        end

        it "returns #{count} image(s)" do
          get path
          response_body = JSON.parse(last_response.body)
          expect(response_body['data']).to_not be_nil
          expect(response_body['data'].length).to eql(count)
          response_body['data'].each do |image|
            expect(image['tags']).to_not be_nil
            expect(image['tags']['foo']).to eql('bar')
          end
        end
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
        expect(image.keys).to eql(%w(name))
      end
    end
  end

  describe 'POST /images/search' do
    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete

      3.times do |n|
        JobBoard::Services::CreateImage.run(
          params: {
            'infra' => 'test',
            'name' => "test-image-#{n}",
            'is_default' => (n == 0),
            'tags' => {
              'foo' => 'bar',
              'production' => (n.even? ? 'nope' : 'yep')
            }
          }
        )
      end
    end

    {
      'with infra & wildcard name' => [%w(infra=test&name=.*), 1],
      'with infra & limit' =>
        [%w(infra=test&limit=3), 3],
      'with infra & tags' =>
        [%w(infra=test&tags=foo:bar,production:yep), 1]
    }.each do |desc, (body, count)|
      context desc do
        it 'returns 200' do
          post '/images/search', body.join("\n"),
               'CONTENT_TYPE' => 'text/uri-list'
          expect(last_response.status).to eql(200)
        end

        it 'returns an array of images' do
          post '/images/search', body.join("\n"),
               'CONTENT_TYPE' => 'text/uri-list'

          response_body = JSON.parse(last_response.body)
          expect(response_body['data']).to_not be_nil
          expect(response_body['data']).to_not be_empty
          expect(response_body['data'].length).to eql(count)
        end
      end
    end

    {
      'when no queries include "infra"' => %w(foo=test&limit=1 name=whatever)
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
             infra=test&name=whatever&fields[images]=name
           ).join("\n"),
           'CONTENT_TYPE' => 'text/uri-list'

      response_body = JSON.parse(last_response.body)
      expect(response_body).to_not be_empty
      expect(response_body['data']).to_not be_nil
      response_body['data'].each do |image|
        expect(image.keys).to eql(%w(name))
      end
    end
  end

  describe 'POST /images' do
    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete
    end

    {
      'with infra & name' => '/images?infra=test&name=whatever',
      'with infra, name, & is_default' =>
        '/images?infra=test&name=whatever&is_default=true',
      'with infra, name, & tags' =>
        '/images?infra=test&name=whatever&tags=foo:bar'
    }.each do |desc, path|
      context desc do
        it 'returns 201' do
          post path
          expect(last_response.status).to eql(201)
        end

        it 'creates a new image' do
          expect { post path }.to change { JobBoard::Models::Image.count }
        end
      end
    end

    {
      'when no infra param is provided' => '/images',
      'when no name param is provided' => '/images?infra=test'
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

  describe 'DELETE /images' do
    before :each do
      JobBoard::Models::Image.where(infra: 'test').delete

      3.times do |n|
        JobBoard::Services::CreateImage.run(
          params: {
            'infra' => 'test',
            'name' => "test-image-#{n}",
            'is_default' => (n == 0),
            'tags' => {
              'foo' => 'bar',
              'production' => (n.even? ? 'nope' : 'yep')
            }
          }
        )
      end
    end

    {
      'with infra & name' =>
        ['/images?infra=test&name=test-image-0&limit=10', 204],
      'with infra, name & tags production:yep' =>
        ['/images?infra=test&name=test-image-0' \
         '&tags=production:yep&limit=10', 204]
    }.each do |desc, (path, status)|
      context desc do
        it "returns #{status}" do
          delete path
          expect(last_response.status).to eql(status)
        end

        it 'deletes matching image(s)' do
          expect do
            delete path
            expect(last_response.body).to be_empty
          end.to change { JobBoard::Models::Image.count }.by(-1)
        end
      end
    end
  end
end
