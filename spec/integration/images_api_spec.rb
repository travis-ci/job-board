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
        ['/images?infra=test&name=foo&limit=10', 1],
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

        it 'returns images' do
          get path
          body = JSON.parse(last_response.body)
          expect(body['data']).to_not be_nil
          expect(body['data']).to_not be_empty
          expect(body['data'].length).to eql(count)
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
end
