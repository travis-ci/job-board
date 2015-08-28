require 'rack/auth/basic'
require './imgref'

use Rack::Auth::Basic, 'SECRET AREA' do |username, password|
  password == 'x' && username == ENV['AUTH_TOKEN']
end

run IMGRef
