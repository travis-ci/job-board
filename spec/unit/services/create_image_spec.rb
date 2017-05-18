# frozen_string_literal: true

describe JobBoard::Services::CreateImage do
  it 'has params' do
    expect(subject.params).to_not be_nil
  end

  it 'creates an image' do
    create_params = {
      'infra' => 'test',
      'name' => 'whatever',
      'is_default' => false,
      'tags' => { production: false }
    }
    expect(JobBoard::Models::Image).to receive(:create).with(
      create_params.symbolize_keys.merge(
        tags: Sequel.hstore(create_params['tags'])
      )
    )
    described_class.run(params: create_params)
  end
end
