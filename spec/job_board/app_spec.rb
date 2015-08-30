describe JobBoard::App do
  before do
    allow(JobBoard::Services::CreateImage).to receive(:run)
      .and_return(build(:image))
    allow(JobBoard::Services::FetchImages).to receive(:run)
      .and_return(build_list(:image, 3))
  end

  it 'has some auth tokens' do
    expect(described_class.auth_tokens).to_not be_nil
  end

  describe 'GET /' do
    it 'redirects to /images' do
      get '/'
      expect(last_response.status).to eql(301)
      expect(URI(last_response.location).path).to eql('/images')
    end
  end

  describe 'POST /images' do
    it 'requires infra param' do
      post '/images'
      expect(last_response.status).to eql(400)
    end

    it 'requires name param' do
      post '/images?infra=test'
      expect(last_response.status).to eql(400)
    end

    it 'creates a new image' do
      post '/images?infra=test&name=whatever'
      expect(last_response.status).to eql(201)
    end
  end

  describe 'GET /images' do
    it 'requires infra param' do
      get '/images'
      expect(last_response.status).to eql(400)
    end

    it 'returns an array of images' do
      get '/images?infra=test'
      expect(last_response.body).to_not be_empty
      expect(JSON.parse(last_response.body)['data']).to_not be_nil
      expect(JSON.parse(last_response.body)['data'].length).to eql(3)
    end
  end
end
