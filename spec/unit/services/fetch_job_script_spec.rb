# frozen_string_literal: true

describe JobBoard::Services::FetchJobScript do
  let :job_data do
    {
      'type' => 'test',
      'config' => {
        'os' => 'linux',
        'env' => ['FOO=foo', 'SECURE BAR=bar']
      },
      'repository' => {
        'github_id' => 42,
        'slug' => 'travis-ci/travis-ci',
        'source_url' => 'git://github.com/travis-ci/travis-ci.git',
        'default_branch' => 'master'
      },
      'build' => {
        'id' => '1',
        'number' => '1',
        'previous_state' => 'failed'
      },
      'job' => {
        'id' => '1',
        'number' => '1.1',
        'commit' => '313f61b',
        'branch' => 'master',
        'commit_range' => '313f61b..313f61a',
        'commit_message' => 'the commit message',
        'secure_env_enabled' => true
      }
    }
  end

  before :each do
    allow(described_class).to receive(:build_api_conn)
      .and_return(fake_http)
  end

  let :fake_http do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post('/script') { |_env| [200, {}, "#!/bin/bash\necho nope\n"] }
    end

    Faraday.new do |conn|
      conn.adapter :test, stubs
    end
  end

  it 'fetches a script' do
    script = described_class.run(job_data: job_data)
    expect(script.length).to be_positive
    expect(script).to match(/bash/)
  end
end
