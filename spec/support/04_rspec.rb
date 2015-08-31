integration_enabled = ENV['INTEGRATION_SPECS'] == '1'

RSpec.configure do |c|
  c.include RackTestBits
  c.include FactoryGirl::Syntax::Methods
  c.filter_run_excluding(integration: true) unless integration_enabled
end
