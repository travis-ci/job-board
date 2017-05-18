# frozen_string_literal: true

require 'sequel/model'

module JobBoard
  module Models
    class Job < Sequel::Model(Sequel.qualify('job_board', 'jobs'))
      set_primary_key :id

      plugin :timestamps, update_on_create: true
    end
  end
end
