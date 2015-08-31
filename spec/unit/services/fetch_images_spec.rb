class FakeImageQuery
  attr_reader :results, :wheres, :limit
  def initialize(results)
    @results = results
    @wheres = []
    @limit = 1
  end

  def where(*conditions)
    @wheres << conditions
    self
  end

  def reverse_order(*)
    self
  end

  def limit(n)
    @limit = n
    @results
  end
end

describe JobBoard::Services::FetchImages do
  subject { described_class.new(params: { 'infra' => 'test' }) }
  let(:image0) { build(:image) }
  let(:results) { build_list(:image, 3) }

  it 'has params' do
    expect(subject.params).to_not be_nil
  end

  it 'fetches images' do
    expect(JobBoard::Models::Image).to receive(:where).with(infra: 'test')
      .and_return(FakeImageQuery.new(results))

    fetch_params = { 'infra' => 'test', 'limit' => 10 }
    expect(described_class.run(params: fetch_params)).to eql(results)
  end

  context 'when tags are provided' do
    it 'extends the query to check tag set membership' do
      query = FakeImageQuery.new(results)
      expect(JobBoard::Models::Image).to receive(:where).with(
        infra: 'test'
      ).and_return(query)

      fetch_params = {
        'infra' => 'test', 'limit' => 10, 'tags' => { 'a' => 'b' }
      }
      expect(described_class.run(params: fetch_params)).to eql(results)
      expect(query.wheres).to include(['tags @> ?', Sequel.hstore('a' => 'b')])
    end
  end

  context 'when no images are found' do
    it 'returns the default image for the infra' do
      expect(JobBoard::Models::Image).to receive(:where).with(
        infra: 'test'
      ).and_return(FakeImageQuery.new([]))

      expect(JobBoard::Models::Image).to receive(:where).with(
        infra: 'test', is_default: true
      ).and_return([image0])

      fetch_params = { 'infra' => 'test', 'limit' => 10 }
      expect(described_class.run(params: fetch_params)).to eql([image0])
    end
  end
end
