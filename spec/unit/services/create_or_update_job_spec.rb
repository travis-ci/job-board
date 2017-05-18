# frozen_string_literal: true

describe JobBoard::Services::CreateOrUpdateJob do
  subject do
    described_class.new(job: job, site: site)
  end

  let(:job_id) { (Time.now.to_i + rand(100..199)).to_s }
  let(:site) { 'test' }
  let :job do
    {
      'id' => job_id,
      'data' => {
        'queue' => 'builds.rad',
        'config' => {
          'language' => 'blip'
        }
      }
    }
  end

  context 'with a new job id' do
    before :each do
      allow(subject).to receive(:cleaned)
        .and_return(job)
    end

    it 'creates a new database record' do
      expect(subject).to receive(:create_new)
        .with(job_id: job_id, site: site, queue_name: 'rad', data: anything)
        .and_return(new: :jorb, woop: :woop)
      expect(subject.run).to eql(new: :jorb, woop: :woop)
    end
  end

  context 'with an existing job id' do
    let :fake_db_job do
      double('job')
    end

    before :each do
      allow(subject).to receive(:cleaned)
        .and_return(job)
      allow(JobBoard::Models::Job).to receive(:first)
        .with(job_id: job_id.to_s)
        .and_return(fake_db_job)
    end

    it 'creates a new database record' do
      expect(fake_db_job).to receive(:set_all)
        .with(site: site, queue: 'rad', data: anything)
      expect(fake_db_job).to receive(:save_changes).and_return(true)
      expect(fake_db_job).to receive(:to_hash)
        .and_return(new: :jorb, woop: :woop)
      expect(subject.run).to eql(new: :jorb, woop: :woop)
    end
  end

  context 'with queue assigned by scheduler' do
    it 'accepts scheduler assigned queue' do
      expect(subject.send(:queue)).to eq('rad')
    end
  end

  context 'without queue assigned by scheduler' do
    let :job do
      {
        'id' => job_id,
        'data' => {
          'config' => {
            'language' => 'bloop'
          }
        }
      }
    end

    before do
      allow(JobBoard::Services::FetchQueue).to receive(:run).and_return('meh')
    end

    it 'assigns queue locally' do
      expect(subject.send(:queue)).to eq('meh')
    end
  end
end
