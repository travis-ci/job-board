# vim:filetype=ruby
#
if ENV['COVERAGE'] == '1'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/db/'
    minimum_coverage 90
  end
end
