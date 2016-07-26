# frozen_string_literal: true
describe JobBoard::Services::UpdateImage do
  let(:image0) { build(:image) }

  it 'has params' do
    expect(subject.params).to_not be_nil
  end

  it 'updates an image' do
    update_params = {
      'infra' => 'test',
      'name' => 'whatever',
      'is_default' => false,
      'tags' => { production: false }
    }
    expect(JobBoard::Models::Image).to receive(:where).and_return([image0])
    expected_params = update_params.symbolize_keys.merge(
      tags: Sequel.hstore(update_params['tags'])
    )
    expect(image0).to receive(:update).with(expected_params)
    described_class.run(params: update_params)
  end

  context 'when the image does not exist' do
    it 'is a no-op' do
      expect(JobBoard::Models::Image).to receive(:where).and_return([])
      expect(
        described_class.run(
          params: { 'infra' => 'test', 'name' => 'whatever' }
        )
      ).to eql(nil)
    end
  end
end
