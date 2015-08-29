require 'sequel/model'

module IMGRef
  module Models
    class Override < Sequel::Model(:imgref__overrides)
      many_to_one :image
      set_primary_key :id

      plugin :timestamps, update_on_create: true
    end
  end
end
