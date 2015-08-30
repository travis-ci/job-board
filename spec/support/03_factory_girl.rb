require 'job_board'
require 'factory_girl'

FactoryGirl.define do
  factory :image, class: JobBoard::Models::Image do
    to_create(&:save)
  end

  factory :job_route_override, class: JobBoard::Models::JobRouteOverride do
  end
end
