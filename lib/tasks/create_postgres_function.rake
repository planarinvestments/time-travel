namespace :time_travel do
  desc "creates sql function used by time_travel gem to manage history"
  task create_postgres_function: :environment do
    TimeTravel::SqlFunctionHelper.create
  end
end
