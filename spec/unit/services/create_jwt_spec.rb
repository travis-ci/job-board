# frozen_string_literal: true

describe JobBoard::Services::CreateJWT do
  let(:job_id) { (Time.now.to_i + rand(100..199)).to_s }

  subject do
    inst = described_class.new(job_id: job_id)
    inst.instance_variable_set(:@alg, 'none')
    allow(inst).to receive(:private_key).and_return(nil)
    inst
  end

  it 'generates a jwt' do
    jwt = subject.run
    expect(jwt).to_not be_empty
    expect(jwt.split('.').length).to be > 1
    decoded = JWT.decode(jwt, nil, false).fetch(0)
    expect(decoded).to_not be_nil
    expect(decoded['sub']).to eq(job_id)
    expect(decoded['exp']).to be > Time.now.to_i
    expect(decoded['iss']).to_not be_empty
  end
end
