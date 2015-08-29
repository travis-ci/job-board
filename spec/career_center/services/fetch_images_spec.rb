describe CareerCenter::Services::FetchImages do
  subject { described_class.new(params: { 'infra' => 'test' }) }

  it 'has params' do
    expect(subject.params).to_not be_nil
  end
end
