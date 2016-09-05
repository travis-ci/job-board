# frozen_string_literal: true
require 'sinatra/base'
require 'sinatra/param'

module JobBoard
  module AppHelpers
    def guest?
      (env['REMOTE_USER'] || 'notset') == 'guest'
    end

    def set_images_mutation_params
      param :infra, String, blank: true, required: true
      param :is_default, Sinatra::Param::Boolean
      param :is_active, Sinatra::Param::Boolean
      param :tags, Hash, default: {}
      param :name, String, blank: true, required: true,
                           format: images_name_format
    end

    def set_image_fetching_params
      param :infra, String, blank: true, required: true
      param :name, String, blank: true
      param :tags, Hash, default: {}
      param :limit, Integer, default: 0
      param :is_default, Sinatra::Param::Boolean, default: false
      param :is_active, Sinatra::Param::Boolean, default: true
    end

    def images_name_format
      @images_name_format ||= /#{JobBoard.config.images_name_format}/
    end
  end

  Sinatra::Base.helpers AppHelpers
end
