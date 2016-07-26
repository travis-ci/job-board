# frozen_string_literal: true
Dir.glob(File.expand_path('../support/*.rb', __FILE__)) do |support_file|
  require "support/#{File.basename(support_file, '.rb')}"
end
