require 'sequel/model'

module JobBoard
  module Models
    class JobRouteOverride < Sequel::Model(:job_board__job_route_overrides)
      many_to_one :image
      set_primary_key :id

      plugin :timestamps, update_on_create: true
    end
  end
end
