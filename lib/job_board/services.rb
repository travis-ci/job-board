# frozen_string_literal: true
module JobBoard
  module Services
    autoload :ActivateImages, 'job_board/services/activate_images'
    autoload :CreateImage, 'job_board/services/create_image'
    autoload :DeleteImages, 'job_board/services/delete_images'
    autoload :FetchImages, 'job_board/services/fetch_images'
    autoload :RestoreImage, 'job_board/services/restore_image'
    autoload :UpdateImage, 'job_board/services/update_image'
  end
end
