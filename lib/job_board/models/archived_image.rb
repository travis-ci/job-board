# frozen_string_literal: true
require 'sequel/model'

module JobBoard
  module Models
    class ArchivedImage < Sequel::Model(:job_board__archived_images)
      set_primary_key :id

      plugin :timestamps, update_on_create: true
    end
  end
end
