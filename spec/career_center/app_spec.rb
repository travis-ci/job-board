describe CareerCenter::App do
  it 'has some auth tokens' do
    expect(described_class.auth_tokens).to_not be_nil
  end
end
