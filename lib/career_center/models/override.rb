require 'sequel/model'

module CareerCenter
  module Models
    class Override < Sequel::Model(:career_center__overrides)
      many_to_one :image
      set_primary_key :id

      plugin :timestamps, update_on_create: true
    end
  end
end
