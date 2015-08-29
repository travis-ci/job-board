require 'sequel/model'

module CareerCenter
  module Models
    class Image < Sequel::Model(:career_center__images)
      set_primary_key :id

      plugin :timestamps, update_on_create: true
    end
  end
end
