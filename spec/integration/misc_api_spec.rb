# frozen_string_literal: true
describe 'Misc API', integration: true do
  describe 'GET /' do
    let(:auth) { %w(guest guest) }

    before do
      authorize(*auth)
    end

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
end
