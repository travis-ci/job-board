describe 'Images API', integration: true do
  describe 'POST /images' do
    context 'when no infra param is provided' do
      it 'returns 400' do
        post '/images'
        expect(last_response.status).to eql(400)
      end

      it 'creates no image' do
        expect do
          post '/images'
        end.to_not change { JobBoard::Models::Image.count }
      end
    end
  end
end
