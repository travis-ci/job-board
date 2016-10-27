# frozen_string_literal: true

describe JobBoard::JobQueriesTransformer do
  subject do
    described_class.new(job_data_config: job_data_config, infra: infra)
  end

  let(:infra) { 'gce' }
  let(:os) { 'linux' }
  let(:dist) { 'trusty' }
  let(:group) { 'beta' }
  let(:language) { 'ruby' }
  let(:osx_image) { '' }
  let :job_data_config do
    {
      'os' => os,
      'dist' => dist,
      'group' => group,
      'language' => language,
      'osx_image' => osx_image
    }
  end

  it 'builds queries' do
    queries = subject.queries
    expect(queries).to_not be_empty
    expect(queries.length).to eq(9)
  end

  it 'builds queries of decreasing specificity' do
    queries = subject.queries
    max_len = queries.map(&:to_hash).map(&:size).max
    queries.each do |query|
      qh = query.to_hash
      expect(qh.size).to be <= max_len
      max_len = qh.size
    end
  end

  context 'when on macos' do
    let(:os) { 'osx' }
    let(:osx_image) { 'xcode6.9' }

    it 'builds queries that exclude dist' do
      expect(subject.queries.all? { |q| !q.to_hash.key?('dist') }).to be true
    end
  end
end
