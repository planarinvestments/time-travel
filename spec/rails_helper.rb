ENV['RAILS_ENV'] ||= 'test'
require "active_record/railtie"
require 'rspec/rails'
require 'byebug'
require 'time_travel'

ActiveRecord::Migration.maintain_test_schema!
def db_connect(db_name)
  isLocal=true
  db_host="postgres"
  db_username="postgres"
  db_password="postgres"

  if isLocal == true
    ActiveRecord::Base.establish_connection(adapter:'postgresql', database: db_name)
  else
    ActiveRecord::Base.establish_connection(adapter:'postgresql', host: db_host, username: db_username, password: db_password,  database: db_name)
  end
  ActiveRecord::Base.connection.active?
end
# ActiveRecord::Base.logger = Logger.new(STDOUT)
RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.before(:all) do
    begin
      db_connect('time_travel_test')
    rescue ActiveRecord::NoDatabaseError
      db_connect('postgres')
      ActiveRecord::Base.connection.create_database 'time_travel_test'
      ActiveRecord::Base.clear_all_connections!
      db_connect('time_travel_test')
    end

    TimeTravel::SqlFunctionHelper.create

    ActiveRecord::Base.connection.create_table :balances do |t|
      t.integer :cash_account_id
      t.integer :amount
      t.integer :reference_id
      t.datetime :effective_from
      t.datetime :effective_till
      t.datetime :valid_from
      t.datetime :valid_till
    end unless ActiveRecord::Base.connection.table_exists? 'balances'
    ActiveRecord::Base.connection.create_table :balances_multiple_attrs do |t|
      t.integer :cash_account_id
      t.integer :amount
      t.string :currency
      t.integer :interest
      t.integer :reference_id
      t.datetime :effective_from
      t.datetime :effective_till
      t.datetime :valid_from
      t.datetime :valid_till
    end unless ActiveRecord::Base.connection.table_exists? 'balances_multiple_attrs'
    ActiveRecord::Base.connection.create_table :blocked_entries do |t|
      t.integer :wrapper_id
      t.integer :req_id
      t.string :req_type
      t.decimal :amount
      t.datetime :effective_from
      t.datetime :effective_till
      t.datetime :valid_from
      t.datetime :valid_till
    end unless ActiveRecord::Base.connection.table_exists? 'blocked_entries'
    ActiveRecord::Base.connection.create_table :performance_data do |t|
      t.integer :amount
      t.integer :status
      t.integer :wrapper_id
      t.string :reporting_currency
      t.datetime :effective_from
      t.datetime :effective_till
      t.datetime :valid_from
      t.datetime :valid_till
    end unless ActiveRecord::Base.connection.table_exists? 'performance_data'
  end

  config.after(:all) do
    ActiveRecord::Base.clear_all_connections!
    postgres_connection = db_connect('postgres')
    ActiveRecord::Base.connection.drop_database 'time_travel_test'
    ActiveRecord::Base.clear_all_connections!
  end
end
