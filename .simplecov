# vim:filetype=ruby
#
if ENV['COVERAGE']
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/db/'
  end
end
