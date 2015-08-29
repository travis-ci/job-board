describe CareerCenter::Config do
  subject { described_class.load }

  it 'has a class env' do
    expect(described_class.env).to_not be_empty
  end

  it 'has an instance env' do
    expect(subject.env).to_not be_empty
  end
end
