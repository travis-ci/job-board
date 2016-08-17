# frozen_string_literal: true
describe JobBoard::Auth do
  let(:tokens) { %w(abc123 secret).join(':') }

  before do
    allow(subject).to receive(:raw_auth_tokens).and_return(tokens)
  end

  it 'has some auth tokens' do
    expect(subject.send(:auth_tokens)).to_not be_nil
  end

  context 'with ","-delimited user:pass auth tokens' do
    let(:tokens) { %w(foo:bar admin:yah).join(',') }

    it 'rejects unknown user:pass combinations' do
      expect(subject.send(:authorized?, 'foo', 'nope')).to eq(false)
    end

    it 'allows known user:pass combinations' do
      expect(subject.send(:authorized?, 'foo', 'bar')).to eq(true)
    end

    it 'rejects known passwords with unknown users' do
      expect(subject.send(:authorized?, 'foo', 'bar')).to eq(true)
    end
  end
end
