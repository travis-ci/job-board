# frozen_string_literal: true

begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'
rescue LoadError => e
  warn e
end

RSpec::Core::RakeTask.new if defined?(RSpec)

RuboCop::RakeTask.new if defined?(RuboCop)

task default: %i[rubocop spec]

task :routes do
  $LOAD_PATH << File.expand_path('../lib', __FILE__)
  ENV['DATABASE_SQL_LOGGING'] = nil
  require 'job_board'

  %w[GET POST PUT DELETE].each do |verb|
    (JobBoard::App.routes[verb] || []).each do |route|
      printf "%8s -> ^#{route.first.inspect}$", verb
    end
  end
end
