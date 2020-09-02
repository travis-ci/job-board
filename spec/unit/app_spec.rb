# frozen_string_literal: true

describe JobBoard::App do
  let(:image0) { build(:image) }
  let(:auth) { %w[guest guest] }

  before do
    allow_any_instance_of(JobBoard::Auth).to receive(:auth_tokens)
      .and_return(%w[secret])
    basic_authorize(*auth)
    allow(JobBoard::Services::CreateImage).to receive(:run)
      .and_return(image0)
    allow(JobBoard::Services::FetchImages).to receive(:run)
      .and_return(build_list(:image, 3))
    allow(JobBoard::Services::UpdateImage).to receive(:run)
      .and_return(image0)
  end

  describe 'POST /images' do
    let(:auth) { %w[admin secret] }

    it 'requires infra param' do
      post '/images'
      expect(last_response.status).to eql(400)
    end

    it 'requires name param' do
      post '/images?infra=test'
      expect(last_response.status).to eql(400)
    end

    it 'creates a new image' do
      post '/images?infra=test&name=test-image'
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
      expect(last_response.status).to eql(200)
      expect(last_response.body).to_not be_empty
      expect(JSON.parse(last_response.body)['data']).to_not be_nil
      expect(JSON.parse(last_response.body)['data'].length).to eql(3)
    end
  end

  describe 'POST /images/search' do
    it 'returns empty dataset if no queries include "infra"' do
      post '/images/search',
           %w[foo=test name=test-image].join("\n"),
           'CONTENT_TYPE' => 'text/uri-list'

      expect(last_response.status).to eql(200)
      expect(last_response.body).to_not be_empty
      expect(JSON.parse(last_response.body)['data']).to_not be_nil
      expect(JSON.parse(last_response.body)['data'].length).to eql(0)
    end

    xit 'returns an array of images' do
      post '/images/search',
           %w[infra=test infra=test&name=test-image].join("\n"),
           'CONTENT_TYPE' => 'text/uri-list'

      expect(last_response.status).to eql(200)
      expect(last_response.body).to_not be_empty
      expect(JSON.parse(last_response.body)['data']).to_not be_nil
      expect(JSON.parse(last_response.body)['data'].length).to eql(3)
    end

    xit 'returns the matching query' do
      post '/images/search',
           %w[infra=test infra=test&name=test-image].join("\n"),
           'CONTENT_TYPE' => 'text/uri-list'

      expect(last_response.status).to eql(200)
      expect(last_response.body).to_not be_empty
      expect(JSON.parse(last_response.body)['meta']).to_not be_nil
      expect(
        JSON.parse(last_response.body)['meta']['matching_query']
      ).to eql('infra' => 'test', 'limit' => 1, 'is_default' => false)
    end
  end

  describe 'PUT /images' do
    let(:auth) { %w[admin secret] }

    it 'requires infra param' do
      put '/images'
      expect(last_response.status).to eql(400)
    end

    it 'requires name param' do
      put '/images?infra=test'
      expect(last_response.status).to eql(400)
    end

    it 'updates the updated image' do
      put '/images?infra=test&name=test-image'
      expect(last_response.status).to eql(200)
    end
  end
end
