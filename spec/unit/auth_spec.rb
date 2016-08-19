# frozen_string_literal: true
RequestAuth = Struct.new('RequestAuth', :username, :password) do
  def credentials
    [username, password]
  end
end

describe JobBoard::Auth do
  subject { described_class.new(nil) }

  let(:tokens) { %w(abc123 secret).join(':') }

  it 'pulls its raw auth tokens from JobBoard.config' do
    expect(JobBoard).to receive_message_chain(:config, :auth, :tokens)
      .and_return('hay:there')
    expect(subject.send(:raw_auth_tokens)).to eq('hay:there')
  end

  context 'with stubbed raw auth tokens' do
    before do
      allow(subject).to receive(:raw_auth_tokens).and_return(tokens)
    end

    it 'has some auth tokens' do
      expect(subject.send(:auth_tokens)).to_not be_nil
    end

    context 'with ","-delimited user:pass auth tokens' do
      let(:tokens) { %w(foo:bar admin:yah).join(',') }

      it 'rejects unknown user:pass combinations' do
        expect(subject.send(:valid?, RequestAuth.new('foo', 'nope')))
          .to eq(false)
      end

      it 'allows known user:pass combinations' do
        expect(subject.send(:valid?, RequestAuth.new('foo', 'bar')))
          .to eq(true)
      end

      it 'rejects known passwords with unknown users' do
        expect(subject.send(:valid?, RequestAuth.new('foo', 'bar')))
          .to eq(true)
      end
    end
  end
end
