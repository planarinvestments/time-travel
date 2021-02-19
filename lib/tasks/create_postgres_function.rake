namespace :time_travel do
  desc "creates sql function used by time_travel gem to manage history"
  task :create_postgres_function, [:schema] => [:environment] do |task, args|
    TimeTravel::SqlFunctionHelper.create(args[:schema])
  end
end
