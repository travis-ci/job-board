# frozen_string_literal: true

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
  subject { described_class.new(query: query) }
  let(:query) { { 'infra' => 'test' } }
  let(:image0) { build(:image) }
  let(:results) { build_list(:image, 3) }

  it 'has query' do
    expect(subject.query).to_not be_nil
  end

  it 'fetches images' do
    expect(JobBoard::Models::Image).to receive(:where).with(infra: 'test')
      .and_return(FakeImageQuery.new(results))

    fetch_query = { 'infra' => 'test', 'limit' => 10 }
    expect(described_class.run(query: fetch_query)).to eql(results)
  end

  context 'when tags are provided' do
    it 'extends the query to check tag set membership' do
      database_query = FakeImageQuery.new(results)
      expect(JobBoard::Models::Image).to receive(:where).with(
        infra: 'test'
      ).and_return(database_query)

      fetch_query = {
        'infra' => 'test', 'limit' => 10, 'tags' => { 'a' => 'b' }
      }
      expect(described_class.run(query: fetch_query)).to eql(results)
      expect(database_query.wheres).to include(
        [Sequel.lit('tags @> ?', Sequel.hstore('a' => 'b'))]
      )
    end
  end

  context 'when no images are found' do
    it 'returns no images' do
      expect(JobBoard::Models::Image).to receive(:where).with(
        infra: 'test'
      ).and_return(FakeImageQuery.new([]))

      fetch_query = { 'infra' => 'test', 'limit' => 10 }
      expect(described_class.run(query: fetch_query)).to be_empty
    end
  end

  context 'when limit is 0' do
    let(:query) { { 'infra' => 'test', 'limit' => 0 } }

    it 'builds a query without a limit clause' do
      expect(subject.send(:build_database_query).sql.downcase)
        .to_not include('limit')
    end
  end
end
