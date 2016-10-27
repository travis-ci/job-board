# frozen_string_literal: true

describe JobBoard::Services::FetchQueue do
  it 'assigns gce for everything' do
    expect(subject.run).to eq('gce')
  end
end
