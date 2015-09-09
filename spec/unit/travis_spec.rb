require 'travis'

describe Travis do
  subject { described_class }

  it 'has a compatibility shim for #config' do
    expect(subject).to respond_to(:config)
    expect(subject.config).to_not be_nil
  end

  it 'has a compatibility shim for #logger' do
    expect(subject).to respond_to(:logger)
    expect(subject.logger).to_not be_nil
  end
end
