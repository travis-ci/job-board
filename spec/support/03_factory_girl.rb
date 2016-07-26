# frozen_string_literal: true
require 'job_board'
require 'factory_girl'

FactoryGirl.define do
  factory :image, class: JobBoard::Models::Image do
    to_create(&:save)
  end
end
