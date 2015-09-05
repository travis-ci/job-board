ENV['RACK_ENV'] = 'test'
ENV['LOG_LEVEL'] = 'fatal'
ENV['DATABASE_URL'] = 'mock://' unless ENV['INTEGRATION_SPECS'] == '1'
ENV['DATABASE_SQL_LOGGING'] = nil
