# frozen_string_literal: true
describe JobBoard::Services::RestoreImage do
  let(:image) { build(:image, restore_params) }
  let :restore_params do
    {
      'infra' => 'test',
      'name' => 'whatever',
      'is_default' => false,
      'is_active' => true,
      'tags' => { production: false }
    }
  end

  it 'has params' do
    expect(subject.params).to_not be_nil
  end

  it 'restores an image' do
    expect(JobBoard::Services::FetchImages).to receive(:run)
      .and_return([image])
    expect(JobBoard::Models::Image).to receive(:create).with(
      restore_params.symbolize_keys.merge(
        tags: Sequel.hstore(restore_params['tags'])
      )
    )
    expect(image).to receive(:destroy)
    described_class.run(params: restore_params)
  end
end
