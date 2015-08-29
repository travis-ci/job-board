require 'sequel/model'

module IMGRef
  module Models
    class Image < Sequel::Model(:imgref__images)
      set_primary_key :id

      plugin :timestamps, update_on_create: true
    end
  end
end
