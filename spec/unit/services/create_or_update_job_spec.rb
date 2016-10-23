# frozen_string_literal: true
describe JobBoard::Services::CreateOrUpdateJob do
  subject do
    described_class.new(job: job, site: site)
  end

  let(:job) { {} }
  let(:site) { 'test' }

  context 'with queue assigned by scheduler' do
    let :job do
      {
        'id' => (Time.now.to_i + rand(100..199)).to_s,
        'data' => {
          'queue' => 'builds.rad'
        }
      }
    end

    it 'accepts scheduler assigned queue' do
      expect(subject.send(:queue)).to eq('rad')
    end
  end

  context 'without queue assigned by scheduler' do
    let :job do
      {
        'id' => (Time.now.to_i + rand(100..199)).to_s,
        'data' => {
          'config' => {
            'language' => 'builds.love'
          }
        }
      }
    end

    before do
      allow(subject).to receive(:assign_queue).and_return('meh')
    end

    it 'assigns queue locally' do
      expect(subject.send(:queue)).to eq('meh')
    end
  end
end
