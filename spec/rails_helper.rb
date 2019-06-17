ENV['RAILS_ENV'] ||= 'test'
require "active_record/railtie"
require 'rspec/rails'
require 'byebug'
require 'time_travel'

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
