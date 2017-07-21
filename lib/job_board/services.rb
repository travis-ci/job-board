# frozen_string_literal: true

module JobBoard
  module Services
    autoload :AllocateJobs, 'job_board/services/allocate_jobs'
    autoload :CreateImage, 'job_board/services/create_image'
    autoload :CreateJWT, 'job_board/services/create_jwt'
    autoload :CreateOrUpdateJob, 'job_board/services/create_or_update_job'
    autoload :DeleteImages, 'job_board/services/delete_images'
    autoload :DeleteJob, 'job_board/services/delete_job'
    autoload :FetchImages, 'job_board/services/fetch_images'
    autoload :FetchJob, 'job_board/services/fetch_job'
    autoload :FetchJobScript, 'job_board/services/fetch_job_script'
    autoload :FetchQueue, 'job_board/services/fetch_queue'
    autoload :SearchJobs, 'job_board/services/search_jobs'
    autoload :UpdateImage, 'job_board/services/update_image'
  end
end
