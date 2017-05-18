# frozen_string_literal: true

module Travis
  def config
    ::JobBoard.config
  end

  module_function :config

  def logger
    nil
  end

  module_function :logger
end
