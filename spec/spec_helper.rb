# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart' if Faraday::VERSION[0].to_i >= 2
require_relative '../lib/faraday/retry'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
end
